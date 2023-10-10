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
  console.log('[e2e worker]', performance.now().toFixed(2), direction, bytes.trim(),
      'len=' + encodedFrame.data.byteLength,
      'type=' + (encodedFrame.type || 'audio'),
      'ts=' + encodedFrame.timestamp,
      'ssrc=' + metadata.synchronizationSource,
      'fid=' + metadata.frameId,
      'dep=' + metadata.dependencies,
      'size=' + metadata.width + 'x' + metadata.height,
      'lidx=' + metadata.spatialIndex,
      'tidx=' + metadata.temporalIndex,
  );
}

function analyzeFunction(encodedFrame, controller) {
  dump(encodedFrame, 'send');
  controller.enqueue(encodedFrame);
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
            transform: analyzeFunction,
        });
        readableStream
            .pipeThrough(transformStream)
            .pipeTo(writableStream);
    } else if (operation === 'initialize') {
        console.log('[e2e worker]', operation);
    }
};
