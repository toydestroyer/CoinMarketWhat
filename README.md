![CoinMarketWhat](misc/logo_main_64.png)

# CoinMarketWhat!? ![](https://github.com/toydestroyer/CoinMarketWhat/actions/workflows/rubocop.yml/badge.svg) ![](https://github.com/toydestroyer/CoinMarketWhat/actions/workflows/rspec.yml/badge.svg)
Inline Telegram bot to answer "How much is %shitcoin% right now?" kind of questions.

## How it works


https://user-images.githubusercontent.com/578554/121365284-18d18500-c96b-11eb-93bb-05ddfe7f2915.mp4





## Deploy
1. Make sure you have [AWS credentials configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) and [AWS SAM CLI installed](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html). User should have permissions to IAM, S3, SNS, SQS, DynamoDB, APIGateway, SSM, Lambda, CloudWatchEvents and CloudFormation.

1. For the first time deployment, run this command to do a guided deploy and generate `samconfig.toml`:

    ```bash
    sam deploy --guided
    ```
    Or this one if you already have `samconfig.toml`
    ```bash
    sam deploy
    ```

3. Take `WebhooksApi` value from the output and use it as the `url` in [`setWebhook`](https://core.telegram.org/bots/api#setwebhook)
4. Go to [AWS System Manager - Parameter Store](https://console.aws.amazon.com/systems-manager/parameters) and set proper values for all `/CoinMarketWhat/*` parameters.
5. Lastly, you should manually trigger the `CacheFunction` to cache available assets and tickers. This needs to be done only once before start using the bot for the first time.

## Thanks

Logo by [Denis Foster](https://www.instagram.com/ikarisindzi/).
