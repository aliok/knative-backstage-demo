const {httpTransport, emitterFor, CloudEvent} = require("cloudevents");

const DEFAULT_EVENT_TYPE = 'com.example.event';
const DEFAULT_SOURCE = 'event-generator';
const DEFAULT_SEND_INTERVAL = 10000;

let eventType = process.env['EVENT_TYPE'];
if (!eventType) {
    console.log(`EVENT_TYPE env var is not defined, gonna use the default event type of ${DEFAULT_EVENT_TYPE}`);
    eventType = DEFAULT_EVENT_TYPE;
}

let source = process.env['SOURCE'];
if (!source) {
    console.log(`SOURCE env var is not defined, gonna use the default source of ${DEFAULT_SOURCE}`);
    source = DEFAULT_SOURCE;
}

let sendInterval = process.env['SEND_INTERVAL'];
if (!sendInterval) {
    console.log(`SEND_INTERVAL env var is not defined, gonna use the default send interval of ${DEFAULT_SEND_INTERVAL}`);
    sendInterval = DEFAULT_SEND_INTERVAL;
} else{
    sendInterval = parseInt(sendInterval, 10);
}

// required
let sinkUrl = process.env['K_SINK'];
if (!sinkUrl) {
    console.error("K_SINK env var is not defined");
    process.exit(1);
}

const SOURCE = 'event-generator';

let i = 0;
function sendEvent() {
    try {
        // Create an emitter to send events to a receiver
        const emit = emitterFor(httpTransport(sinkUrl));

        const data = {
            message: `Hello ${i++}`
        };

        // Create a new CloudEvent
        const ce = new CloudEvent({
            type: eventType,
            source: SOURCE,
            data: data
        });

        // Send it to the endpoint - encoded as HTTP binary by default
        console.log(`Sending event: ${JSON.stringify(ce)} to ${sinkUrl}`);
        emit(ce);
    } catch (err) {
        console.error("Error while sending event:");
        console.error(err);
    }
}

registerGracefulExit();
// send once, then set an interval
sendEvent();
setInterval(sendEvent, sendInterval);

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
