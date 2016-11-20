/**
 * GlueMotorCore.java
 * GlueMotorCore
 *
 * Created by Kazuhisa "Kazu" Terasaki on 9/10/2011.
 * Copyright © 2011-2016 Kazuhisa Terasaki All rights reserved.
 * https://github.com/gluemotor
 */

package com.gluemotor.android;

import android.graphics.PointF;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.util.Log;

public class GlueMotorCore {
    public boolean mLPwmPolarityNegative = false;
    public boolean mRPwmPolarityNegative = false;

    private static final short sSupportedServoCount = 2;
    private static final short sMinValue = -32767;
    private static final short sMaxValue = +32767;
    private static final int sAudioBufferSize = 882;         //= 44.1(samples / 1ms) * 20ms(50Hz)

    private AudioTrack track;
    private short[] audioBuffer = null;
    private int minBufferSize = 0;
    private volatile boolean isRunning;
    private volatile float[] pulseWidth = new float[sSupportedServoCount];
    private volatile float[] nextPulseWidth = new float[sSupportedServoCount];

    public GlueMotorCore() {

    }

    public void enable() {
        startAudioThread();
    }

    public void disable() {
        isRunning = false;
    }

    public void setPulseWidth(float pulseWidth, int servoIndex) {
        nextPulseWidth[servoIndex] = pulseWidth;
    }

    public float getPulseWidth(int servoIndex) {
        return nextPulseWidth[servoIndex];
    }

    protected void startAudioThread() {
        minBufferSize = AudioTrack.getMinBufferSize(44100,
                AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT);
        Log.d("AndroidAudioDevice", "minBufferSize: " + minBufferSize);
        track = new AudioTrack(AudioManager.STREAM_MUSIC, 44100,
                AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT,
                minBufferSize, AudioTrack.MODE_STREAM);
        audioBuffer = new short[sAudioBufferSize * sSupportedServoCount];
        float maxVolume = AudioTrack.getMaxVolume();
        float minVolume = AudioTrack.getMinVolume();
        Log.d("AndroidAudioDevice", "maxVolume: " + maxVolume);
        Log.d("AndroidAudioDevice", "minVolume: " + minVolume);
        track.setStereoVolume(maxVolume, maxVolume);

        isRunning = true;
        new Thread(new Runnable() {
            public void run() {
                while (isRunning) {
                    for (int i = 0; i < sSupportedServoCount; i++) {
                        pulseWidth[i] = nextPulseWidth[i];
                    }

                    short lMinValue = sMinValue;
                    short lMaxValue = sMaxValue;
                    if (mLPwmPolarityNegative) {
                        lMinValue = sMaxValue;
                        lMaxValue = sMinValue;
                    }
                    short rMinValue = sMinValue;
                    short rMaxValue = sMaxValue;
                    if (mRPwmPolarityNegative) {
                        rMinValue = sMaxValue;
                        rMaxValue = sMinValue;
                    }

                    int widthL = Math.round(pulseWidth[0] * 44100.0f);
                    int widthR = Math.round(pulseWidth[1] * 44100.0f);

                    if (widthL > sAudioBufferSize)
                        widthL = sAudioBufferSize;
                    if (widthR > sAudioBufferSize)
                        widthR = sAudioBufferSize;
                    int i;
                    for (i = 0; i < widthL; i++) {
                        audioBuffer[0 + i * 2] = lMaxValue;
                    }
                    for (; i < sAudioBufferSize; i++) {
                        audioBuffer[0 + i * 2] = lMinValue;
                    }
                    for (i = 0; i < widthR; i++) {
                        audioBuffer[1 + i * 2] = rMaxValue;
                    }
                    for (; i < sAudioBufferSize; i++) {
                        audioBuffer[1 + i * 2] = rMinValue;
                    }
                    track.write(audioBuffer, 0, sAudioBufferSize * 2);
                    if (track.getPlayState() != AudioTrack.PLAYSTATE_PLAYING) {
                        track.play();
                    }
                }

                track.stop();
                track = null;
                audioBuffer = null;
            }
        }).start();
    }
}
