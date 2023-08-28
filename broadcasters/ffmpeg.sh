#!/usr/bin/env bash

function show_usage()
{
    echo
    echo "USAGE"
    echo "-----"
    echo
    echo "  SERVER_URL=https://my.mediasoup-demo.org:4443 ROOM_ID=test MEDIA_FILE=./test.mp4 ./ffmpeg.sh"
    echo
    echo "  where:"
    echo "  - SERVER_URL is the URL of the mediasoup-demo API server"
    echo "  - ROOM_ID is the id of the mediasoup-demo room (it must exist in advance)"
    echo "  - MEDIA_FILE is the path to a audio+video file (such as a .mp4 file)"
    echo
    echo "REQUIREMENTS"
    echo "------------"
    echo
    echo "  - ffmpeg: stream audio and video (https://www.ffmpeg.org)"
    echo "  - httpie: command line HTTP client (https://httpie.org)"
    echo "  - jq: command-line JSON processor (https://stedolan.github.io/jq)"
    echo
}

echo

if [ -z "${SERVER_URL}" ] ; then
    >&2 echo "ERROR: missing SERVER_URL environment variable"
    show_usage
    exit 1
fi

if [ -z "${ROOM_ID}" ] ; then
    >&2 echo "ERROR: missing ROOM_ID environment variable"
    show_usage
    exit 1
fi

if [ -z "${MEDIA_FILE}" ] ; then
    >&2 echo "ERROR: missing MEDIA_FILE environment variable"
    show_usage
    exit 1
fi

if [ "$(command -v ffmpeg)" == "" ] ; then
    >&2 echo "ERROR: ffmpeg command not found, must install FFmpeg"
    show_usage
    exit 1
fi

if [ "$(command -v http)" == "" ] ; then
    >&2 echo "ERROR: http command not found, must install httpie"
    show_usage
    exit 1
fi

if [ "$(command -v jq)" == "" ] ; then
    >&2 echo "ERROR: jq command not found, must install jq"
    show_usage
    exit 1
fi

set -e

BROADCASTER_ID=$(LC_CTYPE=C tr -dc A-Za-z0-9 < /dev/urandom | fold -w ${1:-32} | head -n 1)
HTTPIE_COMMAND="http --check-status"
AUDIO_SSRC=1111
AUDIO_PT=100
VIDEO_SSRC=2222
VIDEO_PT=101
VIDEO_CODEC="libvpx-vp9"

#
# Verify that a room with id ROOM_ID does exist by sending a simlpe HTTP GET. If
# not abort since we are not allowed to initiate a room..
#
echo ">>> verifying that room '${ROOM_ID}' exists..."

${HTTPIE_COMMAND} \
    GET ${SERVER_URL}/rooms/${ROOM_ID} --ignore-stdin --verify=no > /dev/null

#
# Create a Broadcaster entity in the server by sending a POST with our metadata.
# Note that this is not related to mediasoup at all, but will become just a JS
# object in the Node.js application to hold our metadata and mediasoup Transports
# and Producers.
#
echo ">>> creating Broadcaster..."

${HTTPIE_COMMAND} \
    POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters \
    id="${BROADCASTER_ID}" \
    displayName="Broadcaster" \
    device:='{"name": "FFmpeg"}' \
    --verify=no \
	--ignore-stdin \
    > /dev/null

#
# Upon script termination delete the Broadcaster in the server by sending a
# HTTP DELETE.
#
trap 'echo ">>> script exited with status code $?"; ${HTTPIE_COMMAND} DELETE ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID} --ignore-stdin --verify=no > /dev/null' EXIT

#
# Create a PlainTransport in the mediasoup to send our audio using plain RTP
# over UDP. Do it via HTTP post specifying type:"plain" and comedia:true and
# rtcpMux:false.
#
echo ">>> creating mediasoup PlainTransport for producing audio..."

res=$(${HTTPIE_COMMAND} \
    POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID}/transports \
    type="plain" \
    comedia:=true \
    rtcpMux:=false \
    --verify=no \
	--ignore-stdin \
    2> /dev/null)

#
# Parse JSON response into Shell variables and extract the PlainTransport id,
# IP, port and RTCP port.
#
eval "$(echo ${res} | jq -r '@sh "audioTransportId=\(.id) audioTransportIp=\(.ip) audioTransportPort=\(.port) audioTransportRtcpPort=\(.rtcpPort)"')"

#
# Create a PlainTransport in the mediasoup to send our video using plain RTP
# over UDP. Do it via HTTP post specifying type:"plain" and comedia:true and
# rtcpMux:false.
#
echo ">>> creating mediasoup PlainTransport for producing video..."

res=$(${HTTPIE_COMMAND} \
    POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID}/transports \
    type="plain" \
    comedia:=true \
    rtcpMux:=false \
    --verify=no \
	--ignore-stdin \
    2> /dev/null)

#
# Parse JSON response into Shell variables and extract the PlainTransport id,
# IP, port and RTCP port.
#
eval "$(echo ${res} | jq -r '@sh "videoTransportId=\(.id) videoTransportIp=\(.ip) videoTransportPort=\(.port) videoTransportRtcpPort=\(.rtcpPort)"')"

#
# Create a mediasoup Producer to send audio by sending our RTP parameters via a
# HTTP POST.
#
echo ">>> creating mediasoup audio Producer..."

${HTTPIE_COMMAND} -v \
    POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID}/transports/${audioTransportId}/producers \
    kind="audio" \
    rtpParameters:="{ \
        \"codecs\": [{ \
            \"mimeType\": \"audio/opus\", \
            \"payloadType\": ${AUDIO_PT}, \
            \"clockRate\": 48000, \
            \"channels\": 2, \
            \"parameters\": { \
                \"sprop-stereo\": 1 \
            } \
        }], \
        \"encodings\": [{ \
            \"ssrc\":${AUDIO_SSRC} \
        }] \
    }" \
    --verify=no \
	--ignore-stdin \
    > /dev/null

#
# Create a mediasoup Producer to send video by sending our RTP parameters via a
# HTTP POST.
#
echo ">>> creating mediasoup video Producer..."

# VP9 (SVC is not working yet)
VIDEO_CODEC_PARAMS=`echo '{ "profile-id": 2, "x-google-start-bitrate": 150000 }' | jq '.'`

${HTTPIE_COMMAND} -v \
    POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID}/transports/${videoTransportId}/producers \
    kind="video" \
    rtpParameters:="{ \
        \"codecs\": [{ \
            \"mimeType\": \"video/vp9\", \
            \"payloadType\": ${VIDEO_PT}, \
            \"clockRate\": 90000, \
            \"parameters\": ${VIDEO_CODEC_PARAMS} \
        }], \
        \"encodings\": [{ \
            \"ssrc\": ${VIDEO_SSRC}, \
            \"maxBitrate\": 50000000, \
            \"scalabilityMode\": \"L3T3_KEY\" \
        }] \
    }" \
    --verify=no \
	--ignore-stdin \
    > /dev/stdout

# H.265 (not working yet)
# VIDEO_CODEC_PARAMS=`echo '{ "level-asymmetry-allowed": 1, "x-google-start-bitrate": 150000 }' | jq '.'`

# ${HTTPIE_COMMAND} -v \
#     POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID}/transports/${videoTransportId}/producers \
#     kind="video" \
#     rtpParameters:="{ \
#         \"codecs\": [{ \
#             \"mimeType\": \"video/h265\", \
#             \"payloadType\": ${VIDEO_PT}, \
#             \"clockRate\": 90000, \
#             \"parameters\": ${VIDEO_CODEC_PARAMS} \
#         }], \
#         \"encodings\": [{ \
#             \"ssrc\": ${VIDEO_SSRC} \
#         }] \
#     }" \
#     --verify=no \
#     > /dev/stdout

# VP8
# ${HTTPIE_COMMAND} -v \
#     POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID}/transports/${videoTransportId}/producers \
#     kind="video" \
#     rtpParameters:="{ \
#         \"codecs\": [{ \
#             \"mimeType\": \"video/vp8\", \
#             \"payloadType\": ${VIDEO_PT}, \
#             \"clockRate\": 90000 \
#         }], \
#         \"encodings\": [{ \
#             \"ssrc\": ${VIDEO_SSRC} \
#         }] \
#     }" \
#     --verify=no \
#     > /dev/stdout

# H.264
# VIDEO_CODEC_PARAMS=`echo '{ "packetization-mode": 1, "profile-level-id": "4d0032", "level-asymmetry-allowed": 1, "x-google-start-bitrate": 150000 }' | jq '.'`

# ${HTTPIE_COMMAND} -v \
#     POST ${SERVER_URL}/rooms/${ROOM_ID}/broadcasters/${BROADCASTER_ID}/transports/${videoTransportId}/producers \
#     kind="video" \
#     rtpParameters:="{ \
#         \"codecs\": [{ \
#             \"mimeType\": \"video/h264\", \
#             \"payloadType\": ${VIDEO_PT}, \
#             \"clockRate\": 90000, \
#             \"parameters\": { \
#                 \"packetization-mode\": 1, \
#                 \"profile-level-id\": \"42e01f\", \
#                 \"level-asymmetry-allowed\": 1 \
#             } \
#         }], \
#         \"encodings\": [{ \
#             \"ssrc\": ${VIDEO_SSRC} \
#         }] \
#     }" \
#     --verify=no \
#     > /dev/stdout

#
# Run ffmpeg command and make it send audio and video RTP with codec payload and
# SSRC values matching those that we have previously signaled in the Producers
# creation above. Also, tell ffmpeg to send the RTP to the mediasoup
# PlainTransports' ip and port.
#
echo ">>> running ffmpeg..."

#
# NOTES:
# - We can add ?pkt_size=1200 to each rtp:// URI to limit the max packet size
#   to 1200 bytes.
#
ffmpeg \
    -re \
    -v info \
    -stream_loop -1 \
    -i ${MEDIA_FILE} \
    -map 0:a:0 \
    -acodec libopus -ab 128k -ac 2 -ar 48000 \
    -map 0:v:0 \
    -pix_fmt yuv420p -c:v ${VIDEO_CODEC} \
    -b:v 2500k -minrate 2500k -maxrate 2500k \
    -deadline realtime -cpu-used 8 -row-mt 1 -tile-columns 2 -strict experimental \
    -ts-parameters "ts_number_layers=3:ts_target_bitrate=500k,1000k,1500k:ts_rate_decimator=4,2,1:ts_periodicity=4:ts_layer_id=0,2,1,2" \
    -f tee \
    "[select=a:f=rtp:ssrc=${AUDIO_SSRC}:payload_type=${AUDIO_PT}]rtp://${audioTransportIp}:${audioTransportPort}?rtcpport=${audioTransportRtcpPort}|[select=v:f=rtp:ssrc=${VIDEO_SSRC}:payload_type=${VIDEO_PT}]rtp://${videoTransportIp}:${videoTransportPort}?rtcpport=${videoTransportRtcpPort}"
