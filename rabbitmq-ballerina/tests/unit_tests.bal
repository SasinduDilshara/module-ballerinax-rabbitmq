// Copyright (c) 2020 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/lang.'string;
import ballerina/log;
import ballerina/runtime;
import ballerina/test;

Client? rabbitmqChannel = ();
Listener? rabbitmqListener = ();
const QUEUE = "MyQueue";
const ACK_QUEUE = "MyAckQueue";
const SYNC_NEGATIVE_QUEUE = "MySyncNegativeQueue";
const DATA_BINDING_QUEUE = "MyDataQueue";
string asyncConsumerMessage = "";
string dataBindingMessage = "";

@test:BeforeSuite
function setup() {
    log:printInfo("Creating a ballerina RabbitMQ channel.");
    Client newClient = new;
    rabbitmqChannel = newClient;
    Client? clientObj = rabbitmqChannel;
    if (clientObj is Client) {
        string? queue = checkpanic clientObj->queueDeclare(QUEUE);
        string? dataBindingQueue = checkpanic clientObj->queueDeclare(DATA_BINDING_QUEUE);
        string? syncNegativeQueue = checkpanic clientObj->queueDeclare(SYNC_NEGATIVE_QUEUE);
        string? ackQueue = checkpanic clientObj->queueDeclare(ACK_QUEUE);
    }
    Listener lis = new;
    rabbitmqListener = lis;
}

@test:Config {
    groups: ["rabbitmq"]
}
public function testChannel() {
    boolean flag = false;
    Client? con = rabbitmqChannel;
    if (con is Client) {
        flag = true;
    }
    test:assertTrue(flag, msg = "RabbitMQ Connection creation failed.");
}

@test:Config {
    dependsOn: ["testChannel"],
    groups: ["rabbitmq"]
}
public function testProducer() {
    Client? channelObj = rabbitmqChannel;
    if (channelObj is Client) {
        string message = "Hello from Ballerina";
        Error? producerResult = channelObj->basicPublish(message.toBytes(), QUEUE);
        if (producerResult is Error) {
            test:assertFail("Producing a message to the broker caused an error.");
        }
        checkpanic channelObj->queuePurge(QUEUE);
    }
}

@test:Config {
    groups: ["rabbitmq"]
}
public function testListener() {
    boolean flag = false;
    Listener? channelListener = rabbitmqListener;
    if (channelListener is Listener) {
        flag = true;
    }
    test:assertTrue(flag, msg = "RabbitMQ Listener creation failed.");
}

@test:Config {
    dependsOn: ["testListener"],
    groups: ["rabbitmq"]
}
public function testAsyncConsumer() {
    string message = "Testing Async Consumer";
    produceMessage(message, QUEUE);
    Listener? channelListener = rabbitmqListener;
    if (channelListener is Listener) {
        checkpanic channelListener.__attach(asyncTestService);
        checkpanic channelListener.__start();
        runtime:sleep(2000);
        test:assertEquals(asyncConsumerMessage, message, msg = "Message received does not match.");
    }
}

@test:Config {
    dependsOn: ["testListener", "testAsyncConsumer"],
    groups: ["rabbitmq"]
}
public function testAcknowledgements() {
    string message = "Testing Message Acknowledgements";
    produceMessage(message, ACK_QUEUE);
    Listener? channelListener = rabbitmqListener;
    if (channelListener is Listener) {
        checkpanic channelListener.__attach(ackTestService);
        runtime:sleep(2000);
    }
}

service asyncTestService =
@ServiceConfig {
    queueName: QUEUE
}
service {
    resource function onMessage(Message message, Caller caller) {
        string|error messageContent = 'string:fromBytes(message.content);
        if (messageContent is string) {
            asyncConsumerMessage = <@untainted> messageContent;
            log:printInfo("The message received: " + messageContent);
        } else {
            log:printError("Error occurred while retrieving the message content.");
        }
    }
};

service ackTestService =
@ServiceConfig {
    queueName: ACK_QUEUE,
    autoAck: false
}
service {
    resource function onMessage(Message message, Caller caller) {
        checkpanic caller->basicAck();
    }
};

function produceMessage(string message, string queueName) {
    Client? clientObj = rabbitmqChannel;
    if (clientObj is Client) {
        checkpanic clientObj->basicPublish(message.toBytes(), queueName);
    }
}
