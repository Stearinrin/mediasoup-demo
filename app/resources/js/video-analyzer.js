/*
 *  Copyright (c) 2020 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree.
 */

/*
 * This is a worker doing the encode/decode transformations to add end-to-end
 * encryption to a WebRTC PeerConnection using the Insertable Streams API.
 */

'use strict';

function dump(encodedFrame, direction, max = 16) {
    const data = new Uint8Array(encodedFrame.data);
    let bytes = '';
    for (let j = 0; j < data.length && j < max; j++) {
        bytes += (data[j] < 16 ? '0' : '') + data[j].toString(16) + ' ';
    }

    const metadata = encodedFrame.getMetadata();

    const len = encodedFrame.data.byteLength;
    const type = (encodedFrame.type || 'audio');
    const ts = encodedFrame.timestamp;
    const ssrc = metadata.synchronizationSource;
    // const csrc = metadata.contributingSources;
    const fid = metadata.frameId;
    const deps = metadata.dependencies;
    const size = metadata.width + 'x' + metadata.height;
    const lidx= metadata.spatialIndex;
    const tidx = metadata.temporalIndex;

    if (type === 'audio') {
        console.log('[e2e worker]', performance.now().toFixed(2),
        direction, bytes.trim(),
            'len=' + len,
            'type=' + type,
            'ts=' + ts,
            'ssrc=' + ssrc,
        );
    } else {
        console.log('[e2e worker]', performance.now().toFixed(2),
        direction, bytes.trim(),
            'len=' + len,
            'type=' + type,
            'ts=' + ts,
            'ssrc=' + ssrc,
            'fid=' + fid,
            'deps=' + deps,
            'size=' + size,
            'lidx=' + lidx,
            'tidx=' + tidx,
        );
    }
}

function analyzeFunction(encodedFrame, controller) {
    dump(encodedFrame, 'send');

    if (encodedFrame.type === undefined) {
        controller.enqueue(encodedFrame);
        return;
    }

    const view = new DataView(encodedFrame.data);

    // Any length that is needed can be used for the new buffer.
    const newData = new ArrayBuffer(encodedFrame.data.byteLength + 8);
    const newView = new DataView(newData);

    // Copy view to newView.
    for (let i = 0; i < encodedFrame.data.byteLength; ++i) {
        newView.setUint8(i, view.getUint8(i));
    }

    // Append frameId.
    const fid = encodedFrame.getMetadata().frameId;
    if (fid > 0xffff) {
        throw new Error('frameId too large: ' + fid);
    }

    for (let i = 0; i < 4; ++i) {
        newView.setUint16(encodedFrame.data.byteLength + 2 * i, fid);
        console.log('frameId', fid);
    }

    encodedFrame.data = newData;

    // let data = new Uint8Array(encodedFrame.data);
    // let bytes = '';
    // for (let j = data.length - 8; j < data.length; j++) {
    //     bytes += (data[j] < 16 ? '0' : '') + data[j].toString(16) + ' ';
    // }
    // console.log('last 8 bytes: ' + bytes.trim());

    controller.enqueue(encodedFrame);

    return;
}

function recordFunction(encodedFrame, controller) {
    dump(encodedFrame, 'recv');

    if (encodedFrame.type === undefined) {
        controller.enqueue(encodedFrame);
        return;
    }

    const view = new DataView(encodedFrame.data);
    const fids = [];

    // let data = new Uint8Array(encodedFrame.data);
    // let bytes = '';
    // for (let j = data.length - 8; j < data.length; j++) {
    //     bytes += (data[j] < 16 ? '0' : '') + data[j].toString(16) + ' ';
    // }
    // console.log('last 8 bytes: ' + bytes.trim());

    for (let i = 0; i < 4; ++i) {
        fids.push(view.getUint16(encodedFrame.data.byteLength - 8 + 2 * i));
        console.log('frameId', fids[i]);
    }

    // assert that all fids are the same
    const fid = fids[0];
    for (let i = 1; i < fids.length; ++i) {
        if (fid !== fids[i]) {
            console.warn('frameId mismatch: ' + fids);
        }
    }

    const newData = new ArrayBuffer(encodedFrame.data.byteLength - 8);
    const newView = new DataView(newData);

    // Copy view to newView.
    for (let i = 0; i < encodedFrame.data.byteLength - 8; ++i) {
        newView.setUint8(i, view.getUint8(i));
    }

    encodedFrame.data = newData;
    controller.enqueue(encodedFrame);

    return;
}

onmessage = async (event) => {
    const { operation } = event.data;
    if (operation === 'produce') {
        console.log('[e2e worker]', operation);
        const {readableStream, writableStream} = event.data;
        const transformStream = new TransformStream({
            transform: analyzeFunction,
        });
        readableStream
            .pipeThrough(transformStream)
            .pipeTo(writableStream);
    } else if (operation === 'consume') {
        console.log('[e2e worker]', operation);
        const {readableStream, writableStream} = event.data;
        const transformStream = new TransformStream({
            transform: recordFunction,
        });
        readableStream
            .pipeThrough(transformStream)
            .pipeTo(writableStream);
    } else if (operation === 'initialize') {
        console.log('[e2e worker]', operation);
    }
};
