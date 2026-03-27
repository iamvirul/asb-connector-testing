# ASB Connector Testing — WSO2 Micro Integrator

A WSO2 Micro Integrator project for testing the **Azure Service Bus (ASB)** connector. Provides three REST APIs that wrap ASB operations for topic/queue/subscription management, message sending, and message receiving.

---

## Project Structure

```
src/main/wso2mi/
├── artifacts/
│   ├── apis/
│   │   ├── admin.xml              # Admin API — topic, subscription, queue, rule management
│   │   ├── MessageReceiver.xml    # Message Receiver API
│   │   └── MessageSender.xml      # Message Sender API
│   ├── local-entries/
│   │   ├── asb_admin_connection.xml
│   │   ├── asb_messagereceiver_connection.xml
│   │   └── messageSender_connection.xml
│   └── sequences/
│       └── CommonFaultSequence.xml
└── resources/
    ├── conf/
    │   └── config.properties      # Connection string, topic, subscription config
    ├── api-definitions/           # OpenAPI specs for all three APIs
    ├── connectors/
    │   └── ballerina-connector-asb-3.8.4.zip
    └── datamapper/
        └── requestMapper/
```

---

## Prerequisites

- Java 11 or higher
- Maven 3.6+
- WSO2 Micro Integrator 4.4.0
- Azure Service Bus namespace with connection string

---

## Configuration

Add below properties to .env and set your actual values:

```properties
connection_string=Endpoint=sb://<namespace>.servicebus.windows.net/;SharedAccessKeyName=<policy>;SharedAccessKey=<key>
topic_name=<your-topic-name>
subscription_name=<your-subscription-name>
```

> **Note:** The `topic_name` and `subscription_name` values are used as defaults in the MessageReceiver and MessageSender connections. You can override them per-request via the request body or query parameters.

---

## Build & Run

### Build

```bash
./mvnw clean install
```

### Deploy & Start

```bash
# Build and deploy in one step
./mvnw clean install -Pdeploy
```

Or use the MI server directly after building:

```bash
# Copy the .car file to MI and start the server
cp target/*.car $MI_HOME/repository/deployment/server/carbonapps/
$MI_HOME/bin/micro-integrator.sh start
```

---

## APIs

All APIs are available at:
- HTTP: `http://localhost:8290`
- HTTPS: `https://localhost:8253`

### 1. Admin API — `/admin`

Manages Azure Service Bus entities (topics, subscriptions, queues, rules).

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/admin/createTopic` | Create a topic |
| GET | `/admin/getTopic` | Get topic details |
| PUT | `/admin/updateTopic` | Update topic properties |
| GET | `/admin/listTopics` | List all topics |
| DELETE | `/admin/deleteTopic/{topicName}` | Delete a topic |
| POST | `/admin/createSubscription` | Create a subscription |
| GET | `/admin/getSubscription` | Get subscription details |
| PUT | `/admin/updateSubscription` | Update a subscription |
| GET | `/admin/listSubscriptions/{topicName}` | List subscriptions for a topic |
| DELETE | `/admin/deleteSubscription` | Delete a subscription |
| GET | `/admin/topicExists/{topicName}` | Check if a topic exists |
| GET | `/admin/subscriptionExists` | Check if a subscription exists |
| POST | `/admin/createRule` | Create a filter rule |
| GET | `/admin/getRule` | Get rule details |
| PUT | `/admin/updateRule` | Update a rule |
| GET | `/admin/listRules` | List rules for a subscription |
| DELETE | `/admin/deleteRule` | Delete a rule |
| POST | `/admin/createQueue` | Create a queue |
| GET | `/admin/getQueue/{queueName}` | Get queue details |
| PUT | `/admin/updateQueue` | Update a queue |
| GET | `/admin/listQueues` | List all queues |
| DELETE | `/admin/deleteQueue` | Delete a queue |
| GET | `/admin/queueExists/{queueName}` | Check if a queue exists |

### 2. Message Sender API — `/messagesender`

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/messagesender/send` | Send a message with properties |
| POST | `/messagesender/sendPayload` | Send message payload only |
| POST | `/messagesender/schedule` | Schedule a message for future delivery |
| GET | `/messagesender/cancel/{sequenceNumber}` | Cancel a scheduled message |
| POST | `/messagesender/sendBatch` | Send a batch of messages |
| GET | `/messagesender/close` | Close the sender connection |

### 3. Message Receiver API — `/messagereceiver`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/messagereceiver/receive` | Receive a single message (PEEK_LOCK) |
| GET | `/messagereceiver/receivePayload` | Receive message payload only |
| GET | `/messagereceiver/receiveBatch/{count}` | Receive a batch of messages |
| GET | `/messagereceiver/close` | Close the receiver connection |

---

## Testing

A shell script is provided for quick API testing. See [`test-apis.sh`](test-apis.sh).

```bash
# Make executable
chmod +x test-apis.sh

# Run all tests
./test-apis.sh

# Run a specific group
./test-apis.sh topic        # Topic operations
./test-apis.sh queue        # Queue operations
./test-apis.sh subscription # Subscription operations
./test-apis.sh message      # Send & receive messages
./test-apis.sh admin        # All admin operations
```

---

## Error Handling

All API resources use a shared `CommonFaultSequence` that returns a structured JSON error response:

```json
{
  "error": {
    "code": "<ERROR_CODE>",
    "message": "<ERROR_MESSAGE>"
  }
}
```

---

## Connection Configuration Details

| Connection | Local Entry Key | Purpose |
|------------|----------------|---------|
| ASB Admin | `ASB_ADMIN_CONNECTION` | Topic/queue/subscription/rule CRUD |
| ASB MessageReceiver | `ASB_MESSAGERECEIVER_CONNECTION` | Consuming messages (PEEK_LOCK mode) |
| ASB MessageSender | `ASB_MESSAGESENDER_CONNECTION` | Publishing and scheduling messages |
