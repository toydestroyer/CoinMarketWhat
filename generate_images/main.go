package main

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"log"
	"net/http"
	"strings"

	"github.com/fogleman/gg"
	"github.com/wcharczuk/go-chart/v2"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/superoo7/go-gecko/v3"
	geckoTypes "github.com/superoo7/go-gecko/v3/types"
)

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	httpClient := &http.Client{}
	cg := coingecko.NewClient(httpClient)

	vsCurrency := request.QueryStringParameters["quote"]
	ids := []string{request.QueryStringParameters["base"]}
	perPage := 1
	page := 1
	order := geckoTypes.OrderTypeObject.MarketCapDesc
	sparkline := true
	pcp := geckoTypes.PriceChangePercentageObject

	market, err := cg.CoinsMarket(vsCurrency, ids, order, perPage, page, sparkline, []string{pcp.PCP24h})
	if err != nil {
		log.Fatal(err)
	}

	current := (*market)[0]

	dc := gg.NewContext(640, 320)

	response, _ := http.Get(current.Image)
	defer response.Body.Close()

	logo, _, _ := image.Decode(response.Body)

	dc.DrawImage(logo, 640-250, 0)

	triangle := "▲"
	percentage_color := color.NRGBA{0, 255, 0, 255}
	chart_color := chart.ColorGreen

	if current.PriceChangePercentage24h < 0.0 {
		triangle = "▼"
		percentage_color = color.NRGBA{255, 0, 0, 255}
		chart_color = chart.ColorRed
	}

	xValues := []float64{}
	yValues := []float64{}

	for i, l := range current.SparklineIn7d.Price {
		xValues = append(xValues, float64(i))
		yValues = append(yValues, l)
	}

	graph := chart.Chart{
		Width:  640,
		Height: 100,
		Background: chart.Style{
			FillColor: chart.ColorTransparent,
			Padding:   chart.Box{0, 0, 0, 0, true},
		},
		Canvas: chart.Style{
			FillColor: chart.ColorTransparent,
		},
		XAxis: chart.HideXAxis(),
		YAxis: chart.HideYAxis(),
		Series: []chart.Series{
			chart.ContinuousSeries{
				Style: chart.Style{
					StrokeColor: chart_color,
					FillColor:   chart_color.WithAlpha(64),
				},
				XValues: xValues,
				YValues: yValues,
			},
		},
	}

	graph_buffer := bytes.NewBuffer([]byte{})
	graph.Render(chart.PNG, graph_buffer)
	buffer := bytes.NewBuffer([]byte{})

	decoded, _, _ := image.Decode(graph_buffer)

	dc.DrawImage(decoded, 0, 220)

	dc.SetRGB(0, 0, 0)

	if err := dc.LoadFontFace("./fonts/FiraSans-Regular.ttf", 40); err != nil {
		panic(err)
	}

	symbol := fmt.Sprintf("%s/%s", current.Symbol, vsCurrency)
	symbol = strings.ToUpper(symbol)

	dc.DrawString(symbol, 10, 40)

	if err := dc.LoadFontFace("./fonts/FiraSans-Light.ttf", 32); err != nil {
		panic(err)
	}

	price := fmt.Sprintf("%f", current.CurrentPrice)
	dc.DrawString(price, 10, 32+40)

	priceW, _ := dc.MeasureString(price)

	if err := dc.LoadFontFace("./fonts/FiraMono-Regular.ttf", 32); err != nil {
		panic(err)
	}

	dc.SetColor(percentage_color)

	dc.DrawString(triangle, priceW+13, 32+40)

	triangleW, _ := dc.MeasureString(triangle)

	if err := dc.LoadFontFace("./fonts/FiraSans-Light.ttf", 32); err != nil {
		panic(err)
	}

	percent_change := fmt.Sprintf("%f%s", current.PriceChangePercentage24h, "%")

	dc.DrawString(percent_change, priceW+triangleW+16, 32+40)

	png.Encode(buffer, dc.Image())

	imgBase64Str := base64.StdEncoding.EncodeToString(buffer.Bytes())

	return events.APIGatewayProxyResponse{
		IsBase64Encoded: true,
		Headers:         map[string]string{"Content-Type": "image/png"},
		Body:            imgBase64Str,
		StatusCode:      200,
	}, nil
}

func main() {
	lambda.Start(handler)
}
