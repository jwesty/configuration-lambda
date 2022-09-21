# configuration-lambda
API Gateway proxy to Lambda to run SSM Associations, with Actions and Slack integration with Terraform.

This tool was created for a way for anyone to easily run scripts that are pre-installed and pre-configured through SSM Assocations. This has been tested mostly on EC2's. For example, if an EC2 needs to run the steps to pull new information or update the local code-base, it would require someone to log into the machine to run the script. This does not scale very well at all. This tool, Configuration Lambda, should be able to solve that. It is not just limited to running the reconfigure scripts, but any script that SSM also has access to run via the Association.

<img width="885" alt="image" src="https://user-images.githubusercontent.com/19826851/191607963-e6c9aff4-7cac-4c73-8dc0-f486bd83391e.png">

##Walkthrough: 
1. The Configuration Orchestrator repository contains the Terraform for the Lambda and API Gateway: https://github.com/jwesty/configuration-lambda/blob/main/api_gateway.tf. The module generated from it is self-contained and the source code and libraries used by the Lambda are built through the main.tf Terraform. The module as referenced will deploy the API Gateway, the Lambda, and the zip file will be built automatically:

2. A .tmp folder will be created by the Terraform that contains a hash file of *.py files, requirements.txt, and main.tf. This way, if there are changes to these files, a new hash will be created and Terraform will detect the changes to the zip file. The repository has a Configuration Orchestration Action (Yaml) that provides several options in terms of Account, Target, Script, and Region for ease of use.


3. For example, the data/payload sent from the Action to the Lambda will look as follows. This is based on the selections made in the Actions. This all hinges on the association name: 

'body': '{"target":"some_instance_name", "region":"us-east-1", "script":"reconfigure", "lambda_key":"secret-key-123", "run_id":"3240324780"}

4. The Lambda takes the data from the payload and will execute the script through SSM via State Manager > Associations. That code is outlined here: https://github.com/jwesty/configuration-lambda/blob/main/configuration-lambda.py#L8

5. One of the first tasks of the Lambda is to validate that the call came from the GitHub Actions. This is a very important safety measure to ensure the actor calling the Lambda was in fact the GitHub Action. The Action passes the key along in the payload set here: Actions as well in the Secret Manager. These keys need to match or else the Lambda will reject the request.
