from __future__ import print_function

import boto3
import json
import decimal

# Helper class to convert a DynamoDB item to JSON.
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            if o % 1 > 0:
                return float(o)
            else:
                return int(o)
        return super(DecimalEncoder, self).default(o)

sqs = boto3.resource('sqs')

print('Loading function')

def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))
    message = event['Records'][0]['Sns']['Message']
    message_to_send = event['Records'][0]['Sns']
    json_msg=json.dumps(message_to_send)
    queue = sqs.get_queue_by_name(QueueName='nagios_alertq.fifo')
    queue.send_message(MessageBody=json_msg, MessageGroupId="Alex")

    msg_to_dict = json.loads(message)
    state_value = msg_to_dict['NewStateValue']
    alarm_name = msg_to_dict['AlarmName']

    if (state_value == "ALARM"):
        update_value = "1"
    else:
        update_value = "0"

    if (alarm_name == "splunk4-SplunkSearchDown") :
        print("calling dynamo db update")
        dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        table = dynamodb.Table('stack_status')
        stack = "splunk4.alexd.com"
        response = table.update_item(
            Key={
                'stack' : stack
            },
            UpdateExpression="set #status.#search = :r",
            ExpressionAttributeValues={
                ':r': decimal.Decimal(update_value)
            },
            ExpressionAttributeNames = {
                '#status': "status",
                '#search': "search",
            },
            ReturnValues="UPDATED_NEW"
        )

        print("UpdateItem succeeded:")
        print(json.dumps(response, indent=4, cls=DecimalEncoder))

    else:
        print("Not a status alarm")

    print("state value is "+str(state_value))
    print("raw event "+str(event))
    print("From SNS: " + str(message))
    return message
