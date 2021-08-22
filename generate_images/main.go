package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/fogleman/gg"
	"github.com/nfnt/resize"
	"github.com/wcharczuk/go-chart/v2"
	"github.com/wcharczuk/go-chart/v2/drawing"

	"github.com/superoo7/go-gecko/v3"
	geckoTypes "github.com/superoo7/go-gecko/v3/types"

	"github.com/leekchan/accounting"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type Params struct {
	Base  string `json:"base"`
	Quote string `json:"quote"`
	Time  int    `json:"random"`
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
	bgColorA       color.NRGBA
	bgColorB       color.NRGBA
	timestampColor color.NRGBA
	tickerColor    color.NRGBA
	nameColor      color.NRGBA
	priceColor     color.NRGBA
	logoPath       string
}

var (
	DarkTheme = &Theme{
		color.NRGBA{13, 27, 41, 255},
		color.NRGBA{1, 23, 45, 255},
		color.NRGBA{52, 73, 94, 255},
		color.NRGBA{255, 255, 255, 255},
		color.NRGBA{171, 171, 171, 255},
		color.NRGBA{255, 255, 255, 255},
		"./images/logo-dark.png",
	}

	LightTheme = &Theme{
		color.NRGBA{236, 240, 241, 255},
		color.NRGBA{243, 247, 248, 255},
		color.NRGBA{171, 171, 171, 255},
		color.NRGBA{47, 46, 51, 255},
		color.NRGBA{171, 171, 171, 255},
		color.NRGBA{47, 46, 51, 255},
		"./images/logo-light.png",
	}
)

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

	httpClient := &http.Client{}
	cg := coingecko.NewClient(httpClient)

	vsCurrency := params.Quote
	ids := []string{params.Base}
	perPage := 1
	page := 1
	order := geckoTypes.OrderTypeObject.MarketCapDesc
	pcp := geckoTypes.PriceChangePercentageObject

	market, err := cg.CoinsMarket(vsCurrency, ids, order, perPage, page, true, []string{pcp.PCP24h})
	if err != nil {
		log.Fatal(err)
	}

	current := (*market)[0]

	dc := gg.NewContext(640, 440)

	direction := DirectionUp

	if current.PriceChangePercentage24h < 0.0 {
		direction = DirectionDown
	}

	xValues := []float64{}
	yValues := []float64{}

	for i, l := range current.SparklineIn7d.Price {
		xValues = append(xValues, float64(i))
		yValues = append(yValues, l)
	}

	dc.DrawRectangle(0, 0, 640, 440)
	g := gg.NewLinearGradient(0, 0, 640, 440)
	g.AddColorStop(0, theme.bgColorA)
	g.AddColorStop(1, theme.bgColorB)
	dc.SetFillStyle(g)
	dc.Fill()

	sparkline := getSparklines(640-(24*2), 129, direction.color, xValues, yValues)

	dc.DrawImage(sparkline, 24, 231)

	dc.SetColor(theme.timestampColor)

	if err := dc.LoadFontFace("./fonts/Lato/Lato-Regular.ttf", 18); err != nil {
		panic(err)
	}

	now := time.Now().UTC().Format(time.RFC1123)
	nowW, nowH := dc.MeasureString(now)
	dc.DrawString(now, 24, 24+nowH+(22-nowH)/2)

	dc.DrawLine(nowW+24+32, 34, 265+351, 34)
	dc.DrawLine(253, 404, 253+363, 404)
	dc.Stroke()

	if err := dc.LoadFontFace("./fonts/Lato/Lato-BoldItalic.ttf", 32); err != nil {
		panic(err)
	}

	dc.SetColor(theme.tickerColor)

	symbol := fmt.Sprintf("%s / %s", current.Symbol, vsCurrency)
	symbol = strings.ToUpper(symbol)

	_, symbolH := dc.MeasureString(symbol)
	dc.DrawString(symbol, 116, 70+symbolH+(38-symbolH)/2)

	if err := dc.LoadFontFace("./fonts/Lato/Lato-Regular.ttf", 18); err != nil {
		panic(err)
	}

	dc.SetColor(theme.nameColor)

	name := current.Name
	_, nameH := dc.MeasureString(name)
	dc.DrawString(name, 116, 108+nameH+(22-nameH)/2)

	if err := dc.LoadFontFace("./fonts/Fira_Sans/FiraSans-Light.ttf", 34); err != nil {
		panic(err)
	}

	dc.SetColor(theme.priceColor)

	lc := accounting.LocaleInfo[vsCurrency]
	ac := accounting.Accounting{Symbol: lc.ComSymbol, Precision: lc.FractionLength, Thousand: lc.ThouSep, Decimal: lc.DecSep}

	log.Printf("%.8f", current.CurrentPrice)
	price := ac.FormatMoney(current.CurrentPrice)
	priceW, priceH := dc.MeasureString(price)
	dc.DrawString(price, 24, 162+priceH+(38-priceH)/2)

	dc.SetColor(direction.color)

	percentChange := fmt.Sprintf(direction.percentChangePattern, current.PriceChangePercentage24h, "%")
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

	response, err := http.Get(current.Image)
	if err != nil {
		panic(err)
	}
	defer response.Body.Close()

	currentLogo, _, _ := image.Decode(response.Body)
	currentLogo = resize.Resize(60, 0, currentLogo, resize.NearestNeighbor)

	dc.DrawImage(currentLogo, 24, 70)

	f, err := os.Open(theme.logoPath)
	if err != nil {
		panic(err)
	}
	defer f.Close()

	logo, _, _ := image.Decode(f)

	dc.DrawImage(logo, 24, 392)

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
	lambda.Start(handler)
}
