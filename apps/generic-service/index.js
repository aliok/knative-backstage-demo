const express = require('express');
const bodyParser = require('body-parser');
const {CloudEvent, HTTP} = require('cloudevents');

const DEFAULT_SOURCE = 'event-generator';

let replyType = process.env['REPLY_TYPE'];
if (!replyType) {
    console.log("REPLY_TYPE env var is not defined, not going to reply.");
}

let source = process.env['SOURCE'];
if (!source) {
    console.log(`SOURCE env var is not defined, gonna use the default source of ${DEFAULT_SOURCE}`);
    source = DEFAULT_SOURCE;
}

const app = express();

app.use(bodyParser.raw({
    inflate: true, limit: '1000kb', type: function (req) {
        return true
    }
}));

app.all('*', function (req, res) {
    console.log("=======================");
    console.log("Request headers:");
    console.log(req.headers)
    console.log("\nRequest body - raw:");
    console.log(req.body)
    console.log("\nRequest body - to string:");
    console.log(String(req.body))
    console.log("=======================\n");

    try {
        const receivedEvent = HTTP.toEvent({headers: req.headers, body: req.body});
        console.log("Received event:");
        console.log(receivedEvent);
        console.log("=======================\n");

        if (!receivedEvent) {
            res.status(400).send('Bad Request');
            return;
        }

        if (!replyType) {
            // do nothing, just respond with 202
            res.status(202).send();
            return;
        }

        const responseEventMessage = new CloudEvent({
            source: source,
            type: replyType,
            data: {
                ...receivedEvent,
            }
        });

        const message = HTTP.binary(responseEventMessage)
        res.set(message.headers)
        res.send(message.body)

    } catch (err) {
        console.log("Error while processing event:");
        console.error(err);
        res.status(415).header("Content-Type", "application/json").send(JSON.stringify(err));
    }
});


app.listen(8080, () => {
    console.log('App listening on :8080');
});


registerGracefulExit();

function registerGracefulExit() {
    let logExit = function () {
        console.log("Exiting");
        process.exit();
    };

    // handle graceful exit
    //do something when app is closing
    process.on('exit', logExit);
    //catches ctrl+c event
    process.on('SIGINT', logExit);
    process.on('SIGTERM', logExit);
    // catches "kill pid" (for example: nodemon restart)
    process.on('SIGUSR1', logExit);
    process.on('SIGUSR2', logExit);
}
