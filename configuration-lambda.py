import json
import os
import boto3
from get_secret import get_secret
import slack_interaction


def lambda_handler(event, context=None):
    # All the data in this section is passed in from the GitHub Action's payload
    target_data = json.loads(event["body"])
    target = target_data["target"]
    region = target_data["region"]
    script = target_data["script"]
    account = target_data["account"]
    run_id = target_data["run_id"]

    log_group_name = os.environ.get("AWS_LAMBDA_LOG_GROUP_NAME")
    formatted_log_group_name = log_group_name.replace(
        "/", "$252F"
    )  # DUMB AWS Formatting on Lambda URLs
    log_stream_name = os.environ.get("AWS_LAMBDA_LOG_STREAM_NAME")
    formatted_log_stream_name = log_stream_name.replace(
        "/", "$252F"
    )  # DUMB AWS Formatting on Lambda URLs
    lambda_log_location = f"https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:" \
                          f"log-groups/log-group/{formatted_log_group_name}/log-events/{formatted_log_stream_name}"
    actions_url = f"https://github.com/<PROJECT>/<REPOSITORY>/actions/runs/{run_id}"

    # This section compares the key set in the Github Actions against the one set in Systems Manager
    lambda_access_key = target_data["lambda_key"]
    secret_manager_lambda_access_key = get_secret()
    print(f"Length of SecretsManager Lambda Key: {len(secret_manager_lambda_access_key)}")
    print(f"Length of GitHub Lambda Key: {len(lambda_access_key)}")

    # If the GitHub secret and SecretManager secret don't match, fail.
    if lambda_access_key != secret_manager_lambda_access_key:
        slack_interaction.key_mismatch_message()
        print(
            "Lambda Access Keys don't match. See: "
            "https://github.com/<REPOSITORY>/terraform/settings/secrets/actions and "
            "https://us-east-1.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-1"
        )
        return {"statusCode": 403}

    else:
        print(f"INFO: Extracted from GitHub Actions: {target}, {region}, {script}")
        ssm_client = boto3.client(
            "ssm",
            region_name=region,
        )
        print(f"INFO: Getting SSM AssociationId for: {target}_{script}")
        list_associations = ssm_client.list_associations(
            AssociationFilterList=[
                {
                    "key": "AssociationName",
                    "value": f"{target}_{script}",
                },
            ],
            MaxResults=30,
        )

        if len(list_associations["Associations"]) < 1:  # {Associations []}
            print(f"ERROR: No SSM Associations named: {target}_{script}")
            slack_interaction.format_failure_message(
                target,
                script,
                account,
                region,
                lambda_log_location,
                actions_url,
            )
            return {"statusCode": 410}

        else:
            for key in list_associations["Associations"]:
                association_id = key["AssociationId"]
                print(
                    f"INFO: Triggering SSM Association for {target}_{script} with AssociationId: {association_id}"
                )
                response = ssm_client.start_associations_once(
                    AssociationIds=[
                        association_id,
                    ]
                )
                if response["ResponseMetadata"]["HTTPStatusCode"] != 200:
                    print(
                        f"ERROR: Triggering {target}_{script} in {region} ({association_id}) was unsuccessful"
                    )

                    slack_interaction.format_failure_message(
                        target,
                        script,
                        account,
                        region,
                        lambda_log_location,
                        actions_url,
                    )
                    return {"statusCode": 418}

                else:
                    print("INFO: Configuration Orchestrator task completed")
                    slack_interaction.format_success_message(
                        target,
                        script,
                        account,
                        region,
                        association_id,
                        lambda_log_location,
                        actions_url,
                    )
                    return {"statusCode": 200}
