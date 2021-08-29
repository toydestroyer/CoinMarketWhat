package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/fogleman/gg"
	"github.com/golang/freetype/truetype"
	"github.com/nfnt/resize"
	"github.com/wcharczuk/go-chart/v2"
	"github.com/wcharczuk/go-chart/v2/drawing"

	"github.com/leekchan/accounting"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
)

type Params struct {
	Base   string `json:"base"`
	Source string `json:"source"`
	Quote  string `json:"quote"`
	Time   int    `json:"random"`
}

type Direction struct {
	isUp                 bool
	color                color.NRGBA
	percentChangePattern string
}

var (
	DirectionUp = &Direction{
		true,
		color.NRGBA{39, 174, 96, 255},
		"+%.2f%s",
	}

	DirectionDown = &Direction{
		false,
		color.NRGBA{231, 76, 60, 255},
		"%.2f%s",
	}
)

type Theme struct {
	bgColor                        []color.NRGBA
	timestamp, ticker, name, price *ThemeFont
	logoPath                       string
}

type ThemeFont struct {
	color                color.NRGBA
	fontName             string
	fontSize, lineHeight uint16
}

func (themeFont *ThemeFont) ApplyToContext(dc *gg.Context) {
	dc.SetColor(themeFont.color)

	face := truetype.NewFace(themeFont.GetFontFace(), &truetype.Options{
		Size: float64(themeFont.fontSize),
	})

	dc.SetFontFace(face)
}

func (themeFont *ThemeFont) GetFontFace() *truetype.Font {
	if fonts[themeFont.fontName] == nil {
		fontBytes, err := ioutil.ReadFile(fmt.Sprintf("./fonts/%s.ttf", themeFont.fontName))
		if err != nil {
			panic(err)
		}

		font, err := truetype.Parse(fontBytes)
		if err != nil {
			panic(err)
		}

		fonts[themeFont.fontName] = font
	}

	return fonts[themeFont.fontName]
}

func (theme *Theme) GetLogo() *image.Image {
	if logos[theme.logoPath] != nil {
		return logos[theme.logoPath]
	}

	f, err := os.Open(theme.logoPath)
	if err != nil {
		panic(err)
	}
	defer f.Close()

	logo, _, _ := image.Decode(f)

	logos[theme.logoPath] = &logo

	return logos[theme.logoPath]
}

var (
	DarkTheme = &Theme{
		// Background colors
		[]color.NRGBA{color.NRGBA{13, 27, 41, 255}, color.NRGBA{1, 23, 45, 255}},
		// timestamp
		&ThemeFont{
			color.NRGBA{52, 73, 94, 255},
			"Lato/Lato-Regular",
			18,
			22,
		},
		// ticker
		&ThemeFont{
			color.NRGBA{255, 255, 255, 255},
			"Lato/Lato-BoldItalic",
			32,
			38,
		},
		// name
		&ThemeFont{
			color.NRGBA{171, 171, 171, 255},
			"Lato/Lato-Regular",
			18,
			22,
		},
		// price
		&ThemeFont{
			color.NRGBA{255, 255, 255, 255},
			"Fira_Sans/FiraSans-Light",
			34,
			38,
		},
		"./images/logo-dark.png",
	}

	LightTheme = &Theme{
		// Background colors
		[]color.NRGBA{color.NRGBA{236, 240, 241, 255}, color.NRGBA{243, 247, 248, 255}},
		// timestamp
		&ThemeFont{
			color.NRGBA{171, 171, 171, 255},
			"Lato/Lato-Regular",
			18,
			22,
		},
		// ticker
		&ThemeFont{
			color.NRGBA{47, 46, 51, 255},
			"Lato/Lato-BoldItalic",
			32,
			38,
		},
		// name
		&ThemeFont{
			color.NRGBA{171, 171, 171, 255},
			"Lato/Lato-Regular",
			18,
			22,
		},
		// price
		&ThemeFont{
			color.NRGBA{47, 46, 51, 255},
			"Fira_Sans/FiraSans-Light",
			34,
			38,
		},
		"./images/logo-light.png",
	}
)

var (
	dynamodbClient *dynamodb.DynamoDB
	fonts          map[string]*truetype.Font
	logos          map[string]*image.Image
)

type Item struct {
	Id                       string    `dynamodbav:"id"`
	Name                     string    `dynamodbav:"name"`
	Symbol                   string    `dynamodbav:"symbol"`
	Image                    string    `dynamodbav:"image"`
	Price                    float64   `dynamodbav:"price"`
	Sparkline                []float64 `dynamodbav:"sparkline"`
	PriceChangePercentage24h float64   `dynamodbav:"price_change_percentage_24h"`
}

func (item *Item) GetLogo() *image.Image {
	log.Printf("Logos in cache: %d", len(logos))

	if logos[item.Id] != nil {
		log.Printf("Reusing logo: %s", item.Id)
		return logos[item.Id]
	}

	log.Printf("Getting logo: %s", item.Id)

	response, err := http.Get(item.Image)
	if err != nil {
		panic(err)
	}

	currentLogo, _, _ := image.Decode(response.Body)
	response.Body.Close()
	resized := resize.Resize(60, 0, currentLogo, resize.NearestNeighbor)
	logos[item.Id] = &resized

	return logos[item.Id]
}

func (item *Item) GetStarklineValues() ([]float64, []float64) {
	xValues := []float64{}
	yValues := []float64{}

	for i, l := range item.Sparkline {
		xValues = append(xValues, float64(i))
		yValues = append(yValues, l)
	}

	return xValues, yValues
}

func getSparklines(width, height int, color color.NRGBA, xValues, yValues []float64) image.Image {
	chartColor := drawing.Color{R: color.R, G: color.G, B: color.B, A: color.A}

	graph := chart.Chart{
		Width:  width,
		Height: height,
		Background: chart.Style{
			FillColor: chart.ColorTransparent,
			Padding:   chart.NewBox(0, 0, 0, 0),
		},
		Canvas: chart.Style{
			FillColor: chart.ColorTransparent,
		},
		XAxis:          chart.HideXAxis(),
		YAxis:          chart.HideYAxis(),
		YAxisSecondary: chart.HideYAxis(),
		Series: []chart.Series{
			chart.ContinuousSeries{
				Style: chart.Style{
					StrokeColor: chart.ColorWhite,
					FillColor:   chart.ColorWhite,
				},
				XValues: xValues,
				YValues: yValues,
			},
		},
	}

	graph_buffer := bytes.NewBuffer([]byte{})
	graph.Render(chart.PNG, graph_buffer)

	decoded, _, _ := image.Decode(graph_buffer)

	dc := gg.NewContext(width, height)
	dc.DrawImage(decoded, 0, 0)

	mask := dc.AsMask()
	dc.Clear()
	g := gg.NewLinearGradient(0, 0, 0, float64(height))
	colorA := color
	colorA.A = 100
	colorB := color
	colorB.A = 0
	g.AddColorStop(0, colorA)
	g.AddColorStop(1, colorB)
	dc.SetFillStyle(g)
	dc.SetMask(mask)
	dc.DrawRectangle(0, 0, float64(width), float64(height))
	dc.Fill()
	dc.ResetClip()

	// TODO: Is it possible to just change Style?
	graph.Series[0] = chart.ContinuousSeries{
		Style: chart.Style{
			StrokeColor: chartColor,
			FillColor:   chart.ColorTransparent,
		},
		XValues: xValues,
		YValues: yValues,
	}

	graph.Render(chart.PNG, graph_buffer)

	decoded, _, _ = image.Decode(graph_buffer)
	dc.DrawImage(decoded, 0, 0)

	return dc.Image()
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	theme := DarkTheme

	decoded_params, _ := base64.RawURLEncoding.DecodeString(request.PathParameters["params"])
	params := Params{}

	_ = json.Unmarshal(decoded_params, &params)

	tableName := "CoinMarketWhatDB"
	resourceId := fmt.Sprintf("%s:%s:%s", params.Base, params.Source, params.Quote)
	log.Printf("ResourceId: %s", resourceId)
	resourceType := "price"

	result, _ := dynamodbClient.GetItem(&dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]*dynamodb.AttributeValue{
			"resource_id": {
				S: aws.String(resourceId),
			},
			"resource_type": {
				S: aws.String(resourceType),
			},
		},
	})

	if result.Item == nil {
		log.Fatalf("Can't find item: %s", result)
	}

	item := Item{}

	_ = dynamodbattribute.UnmarshalMap(result.Item, &item)

	dc := gg.NewContext(640, 440)

	direction := DirectionUp

	if item.PriceChangePercentage24h < 0.0 {
		direction = DirectionDown
	}
	xValues, yValues := item.GetStarklineValues()

	dc.DrawRectangle(0, 0, 640, 440)
	g := gg.NewLinearGradient(0, 0, 640, 440)
	g.AddColorStop(0, theme.bgColor[0])
	g.AddColorStop(1, theme.bgColor[1])
	dc.SetFillStyle(g)
	dc.Fill()

	sparkline := getSparklines(640-(24*2), 129, direction.color, xValues, yValues)

	dc.DrawImage(sparkline, 24, 231)

	theme.timestamp.ApplyToContext(dc)

	now := time.Now().UTC().Format(time.RFC1123)
	nowW, nowH := dc.MeasureString(now)
	dc.DrawString(now, 24, 24+nowH+(22-nowH)/2)

	dc.DrawLine(nowW+24+32, 34, 265+351, 34)
	dc.DrawLine(253, 404, 253+363, 404)
	dc.Stroke()

	theme.ticker.ApplyToContext(dc)

	symbol := fmt.Sprintf("%s / %s", item.Symbol, params.Quote)
	symbol = strings.ToUpper(symbol)

	_, symbolH := dc.MeasureString(symbol)
	dc.DrawString(symbol, 116, 70+symbolH+(38-symbolH)/2)

	theme.name.ApplyToContext(dc)

	name := item.Name
	_, nameH := dc.MeasureString(name)
	dc.DrawString(name, 116, 108+nameH+(22-nameH)/2)

	theme.price.ApplyToContext(dc)

	lc := accounting.LocaleInfo[params.Quote]
	ac := accounting.Accounting{Symbol: lc.ComSymbol, Precision: lc.FractionLength, Thousand: lc.ThouSep, Decimal: lc.DecSep}

	log.Printf("%.8f", item.Price)
	price := ac.FormatMoney(item.Price)
	priceW, priceH := dc.MeasureString(price)
	dc.DrawString(price, 24, 162+priceH+(38-priceH)/2)

	dc.SetColor(direction.color)

	percentChange := fmt.Sprintf(direction.percentChangePattern, item.PriceChangePercentage24h, "%")
	percentChangeW, percentChangeH := dc.MeasureString(percentChange)
	dc.DrawString(percentChange, 24+priceW+32, 162+percentChangeH+(38-percentChangeH)/2)

	if direction.isUp {
		dc.DrawLine(24+priceW+32+percentChangeW+20, 162+10+(38-10)/2, 24+priceW+32+percentChangeW+20+10, 162+(38-10)/2)
		dc.DrawLine(24+priceW+32+percentChangeW+20+10, 162+(38-10)/2, 24+priceW+32+percentChangeW+20+20, 162+10+(38-10)/2)
	} else {
		dc.DrawLine(24+priceW+32+percentChangeW+20, 162+(38-10)/2, 24+priceW+32+percentChangeW+20+10, 162+10+(38-10)/2)
		dc.DrawLine(24+priceW+32+percentChangeW+20+10, 162+10+(38-10)/2, 24+priceW+32+percentChangeW+20+20, 162+(38-10)/2)
	}
	dc.SetLineWidth(2)
	dc.Stroke()

	dc.DrawImage(*item.GetLogo(), 24, 70)
	dc.DrawImage(*theme.GetLogo(), 24, 392)

	buffer := bytes.NewBuffer([]byte{})
	jpeg.Encode(buffer, dc.Image(), &jpeg.Options{Quality: 100})

	imgBase64Str := base64.StdEncoding.EncodeToString(buffer.Bytes())

	return events.APIGatewayProxyResponse{
		IsBase64Encoded: true,
		Headers:         map[string]string{"Content-Type": "image/jpeg"},
		Body:            imgBase64Str,
		StatusCode:      200,
	}, nil
}

func main() {
	awsSession, _ := session.NewSession(&aws.Config{})
	dynamodbClient = dynamodb.New(awsSession)

	logos = make(map[string]*image.Image)
	fonts = make(map[string]*truetype.Font)

	lambda.Start(handler)
}
