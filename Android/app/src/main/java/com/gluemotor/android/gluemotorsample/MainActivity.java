/**
 * MainActivity.java
 * GlueMotorSample
 *
 * Created by Kazuhisa "Kazu" Terasaki on 11/19/2016.
 * Copyright © 2016 Kazuhisa Terasaki All rights reserved.
 * https://github.com/gluemotor
 */

package com.gluemotor.android.gluemotorsample;

import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.widget.CompoundButton;
import android.widget.SeekBar;
import android.widget.Switch;
import android.widget.TextView;

import com.gluemotor.android.GlueMotorCore;

public class MainActivity extends AppCompatActivity {

    private GlueMotorCore mGlueMotor = new GlueMotorCore();

    private TextView mServo0TextView;
    private Switch mServo0Switch;
    private SeekBar mServo0SeekBar;
    private TextView mServo1TextView;
    private Switch mServo1Switch;
    private SeekBar mServo1SeekBar;

    private boolean mServo0PwmEnabled = false;
    private float mServo0PulseWidth = 0.0015f;
    private boolean mServo1PwmEnabled = false;
    private float mServo1PulseWidth = 0.0015f;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_main);

        mServo0TextView = (TextView) findViewById(R.id.textView0);
        mServo0Switch = (Switch) findViewById(R.id.switch0);
        mServo0SeekBar = (SeekBar) findViewById(R.id.seekBar0);
        mServo1TextView = (TextView) findViewById(R.id.textView1);
        mServo1Switch = (Switch) findViewById(R.id.switch1);
        mServo1SeekBar = (SeekBar) findViewById(R.id.seekBar1);

        Switch.OnCheckedChangeListener checkedChangeListener = new Switch.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton sw, boolean on) {
                if (sw == mServo0Switch) {
                    mServo0PwmEnabled = on;
                    updatePulseWidth();
                    updateTextViews();
                }
                else if (sw == mServo1Switch) {
                    mServo1PwmEnabled = on;
                    updatePulseWidth();
                    updateTextViews();
                }
            }
        };
        mServo0Switch.setOnCheckedChangeListener(checkedChangeListener);
        mServo1Switch.setOnCheckedChangeListener(checkedChangeListener);

        SeekBar.OnSeekBarChangeListener seekBarChangedListener = new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                float pulseWidth = (10000 + progress) * 0.0000001f;
                if (seekBar == mServo0SeekBar) {
                    mServo0PulseWidth = pulseWidth;
                    updatePulseWidth();
                    updateTextViews();
                }
                else if (seekBar == mServo1SeekBar) {
                    mServo1PulseWidth = pulseWidth;
                    updatePulseWidth();
                    updateTextViews();
                }
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) { }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) { }
        };
        mServo0SeekBar.setOnSeekBarChangeListener(seekBarChangedListener);
        mServo1SeekBar.setOnSeekBarChangeListener(seekBarChangedListener);
    }

    protected void onResume() {
        super.onResume();

        updatePulseWidth();
        updateTextViews();
        mGlueMotor.enable();
    }

    protected void onPause() {
        super.onPause();

        mGlueMotor.disable();
    }

    protected void updatePulseWidth() {
        mGlueMotor.setPulseWidth(mServo0PwmEnabled ? mServo0PulseWidth : 0f, 0);
        mGlueMotor.setPulseWidth(mServo1PwmEnabled ? mServo1PulseWidth : 0f, 1);
    }

    protected void updateTextViews() {
        String val = String.format("%.03f%s", mServo0PulseWidth * 1000f, "ms");
        if (!mServo0PwmEnabled) {
            val = "OFF";
        }
        mServo0TextView.setText(String.format("Servo 0: %s", val));

        val = String.format("%.03f%s", mServo1PulseWidth * 1000f, "ms");
        if (!mServo1PwmEnabled) {
            val = "OFF";
        }
        mServo1TextView.setText(String.format("Servo 1: %s", val));
    }
}
