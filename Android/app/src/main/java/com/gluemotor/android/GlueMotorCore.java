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
    public volatile boolean mServo0PwmPolarityNegative = false;
    public volatile boolean mServo1PwmPolarityNegative = false;

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
                    if (mServo0PwmPolarityNegative) {
                        lMinValue = sMaxValue;
                        lMaxValue = sMinValue;
                    }
                    short rMinValue = sMinValue;
                    short rMaxValue = sMaxValue;
                    if (mServo1PwmPolarityNegative) {
                        rMinValue = sMaxValue;
                        rMaxValue = sMinValue;
                    }

                    //
                    // Thank you for reading my dirty source code. You are now reaching the GlueMotor's core part.
                    // Rest of the code are pretty obvious, but the next block is only the part that may be considered as "invention",
                    // that I have came up with when I was thinking about how to improve the PWM resolution, and here is how I have solved!
                    // Just in case if you feel something from this idea and want to poke me: email:support@gluemotor.com, twitter:@gluemotor
                    //
                    double widthLd = (double) pulseWidth[0] * 44100.0;
                    double widthRd = (double) pulseWidth[1] * 44100.0;
                    int widthL = (int) Math.floor(widthLd);
                    int widthR = (int) Math.floor(widthRd);
                    short fallEdgeL = (short) ((double) lMinValue + ((double) lMaxValue - (double) lMinValue) * (widthLd - (double) widthL));
                    short fallEdgeR = (short) ((double) rMinValue + ((double) rMaxValue - (double) rMinValue) * (widthRd - (double) widthR));

                    if (widthL > sAudioBufferSize)
                        widthL = sAudioBufferSize;
                    if (widthR > sAudioBufferSize)
                        widthR = sAudioBufferSize;

                    int i;
                    // L channel
                    for (i = 0; i < widthL; i++) {
                        audioBuffer[0 + i * 2] = lMaxValue;
                    }
                    if (i < sAudioBufferSize) {
                        audioBuffer[0 + i * 2] = fallEdgeL;
                        i++;
                    }
                    for (; i < sAudioBufferSize; i++) {
                        audioBuffer[0 + i * 2] = lMinValue;
                    }

                    // R channel
                    for (i = 0; i < widthR; i++) {
                        audioBuffer[1 + i * 2] = rMaxValue;
                    }
                    if (i < sAudioBufferSize) {
                        audioBuffer[1 + i * 2] = fallEdgeR;
                        i++;
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
