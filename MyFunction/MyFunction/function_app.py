import azure.functions as func
import datetime
import json
import logging
import os
from twilio.rest import Client

app = func.FunctionApp()

# Event Hub trigger function
@app.function_name(name="EventHubOrderAlert")
@app.event_hub_message_trigger(
    arg_name="event",
    event_hub_name="orders-stream",
    connection="EventHubConnectionString"
)
def event_hub_order_alert(event: func.EventHubEvent):
    logging.info("Processing Event Hub message...")
    try:
        message_body = event.get_body().decode('utf-8')
        data = json.loads(message_body)
        order_total = float(data.get('order_total', 0))
        phone_number = data.get('phone_number')
        logging.info(f"Order total: £{order_total}, Phone: {phone_number}")
        if order_total > 100 and phone_number:
            # Twilio credentials from environment variables or Key Vault
            account_sid = os.environ.get('TWILIO_ACCOUNT_SID')
            auth_token = os.environ.get('TWILIO_AUTH_TOKEN')
            twilio_from = os.environ.get('TWILIO_FROM_NUMBER')
            if not all([account_sid, auth_token, twilio_from]):
                logging.error("Twilio credentials are not set.")
                return
            client = Client(account_sid, auth_token)
            message = client.messages.create(
                body=f"Order total £{order_total} exceeds £100!",
                from_=twilio_from,
                to=phone_number
            )
            logging.info(f"SMS sent: {message.sid}")
        else:
            logging.info("Order total does not exceed threshold or phone number missing.")
    except Exception as e:
        logging.error(f"Error processing message: {e}")