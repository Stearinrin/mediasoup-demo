/**
 * Insertable streams.
 *
 * https://github.com/webrtc/samples/blob/gh-pages/src/content/insertable-streams/endtoend-encryption/js/main.js
 */

import Logger from './Logger';

const logger = new Logger('videoAnalyzer');

let e2eSupported = undefined;
let worker = undefined;

export function isSupported()
{
	if (e2eSupported === undefined)
	{
		if (RTCRtpSender.prototype.createEncodedStreams)
		{
			try
			{
				const stream = new ReadableStream();

				window.postMessage(stream, '*', [ stream ]);
				worker = new Worker('/resources/js/video-analyzer.js', { name: 'video analyzer' });

				logger.debug('isSupported() | supported');

				e2eSupported = true;
			}
			catch (error)
			{
				logger.debug(`isSupported() | not supported: ${error}`);

				e2eSupported = false;
			}
		}
		else
		{
			logger.debug('isSupported() | not supported');

			e2eSupported = false;
		}
	}

	return e2eSupported;
}

export function initialize()
{
	logger.debug('initialize()');

	assertSupported();

	worker.postMessage(
		{
			operation : 'initialize'
		});
}

export function post(operation, rtpTransport)
{
	logger.debug(
		'set() [operation:%o]', operation);

	assertSupported();

	const encodedStreams = rtpTransport.createEncodedStreams();
	const readableStream = encodedStreams.readable || encodedStreams.readableStream;
	const writableStream = encodedStreams.writable || encodedStreams.writableStream;

	worker.postMessage(
		{
			operation : operation,
			readableStream,
			writableStream
		},
		[ readableStream, writableStream ]
	);
}

function assertSupported()
{
	if (e2eSupported === false)
		throw new Error('e2e not supported');
	else if (e2eSupported === undefined)
		throw new Error('e2e not initialized, must call isSupported() first');
}
