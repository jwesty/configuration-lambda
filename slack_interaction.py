import requests


def post_to_slack(message):
    webhook_url = "https://hooks.slack.com/services/<REPLACE_ME>"
    print(f"INFO: Sending Slack Message {message}")
    response = requests.post(
        webhook_url, data=message, headers={"Content-Type": "application/json"}
    )
    if response.status_code != 200:
        raise ValueError(
            "Request to slack returned an error %s, the response is:\n%s"
            % (response.status_code, response.text)
        )


def format_success_message(
    host, execution_script, environment, region, association_id, log_url, job_url
):
    formatted_message = (
        '{"attachments":[{"color":"#00FF00","blocks":[{"type":"section","text":{"type":"mrkdwn","text":":white_check_mark: Successfully triggered   \n\n Association: *sv_%s_%s* \n Environment: *%s* \n Region: *%s* \n Association ID: *%s*"}},{"type":"divider"},{"type":"section","text":{"type":"mrkdwn","text":"*Actions:*"}},{"type":"actions","elements":[{"type":"button","text":{"type":"plain_text","text":"View Cloudwatch Logs","emoji":true},"url":"%s"},{"type":"button","text":{"type":"plain_text","text":"View Job","emoji":true},"url":"%s"}]}]}]}'
        % (
            host,
            execution_script,
            environment,
            region,
            association_id,
            log_url,
            job_url,
        )
    )
    post_to_slack(formatted_message)


def format_failure_message(
    host, execution_script, environment, region, log_url, job_url
):
    formatted_message = (
        '{"attachments":[{"color":"#FF0000","blocks":[{"type":"section","text":{"type":"mrkdwn","text":":exclamation: *Error*  \n No association found with that name. \n\n Association: *sv_%s_%s* \n Environment: *%s* \n Region: *%s* \n "}},{"type":"divider"},{"type":"section","text":{"type":"mrkdwn","text":"*Actions:*"}},{"type":"actions","elements":[{"type":"button","text":{"type":"plain_text","text":"View Cloudwatch Logs","emoji":true},"url":"%s"},{"type":"button","text":{"type":"plain_text","text":"View Job","emoji":true},"url":"%s"}]}]}]}'
        % (
            host,
            execution_script,
            environment,
            region,
            log_url,
            job_url,
        )
    )
    post_to_slack(formatted_message)


def key_mismatch_message():
    key_mismatch = '{"text": ":exclamation: *Key Mismatch*: Check the GitHub Association and the Secrets Manager"}'
    post_to_slack(key_mismatch)
