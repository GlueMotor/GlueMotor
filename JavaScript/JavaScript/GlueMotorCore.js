//
//  GlueMotorCore.js
//  GlueMotorCore
//
//  Created by Kazuhisa "Kazu" Terasaki on 11/20/2016.
//  Copyright © 2016 Kazuhisa Terasaki All rights reserved.
//  https://github.com/gluemotor
//

var glueMotorCore = {
	pulseWidth: [0, 0],
	pulsePolarityNegative: [false, false],
	
	// parameter:
	//	pulseWidth: pulseWidth in seconds (e.g. center position is 0.0015)
	//	servoIndex: should be 0 (L-channel) or 1 (R-channel)
	setPulseWidth: function(pulseWidth, servoIndex) {
		if (pulseWidth >= 0 && (pulseWidth * 44100) < 510 && servoIndex >= 0 && servoIndex < 2) {
			this.pulseWidth[servoIndex] = pulseWidth
		}
	},
	
	// parameter:
	//	pulsePolarityNegative: true if desired pulse polarity is negative, default is false
	//	servoIndex: should be 0 (L-channel) or 1 (R-channel)
	setPulsePolarityNegative: function(pulsePolarityNegative, servoIndex) {
		if (this.sp && servoIndex >= 0 && servoIndex < 2) {
			this.pulsePolarityNegative[servoIndex] = pulsePolarityNegative;
		}
	},
	
	enable: function() {
		if (this.ac) {
			return
		}
		var ac = new (window.AudioContext || window.webkitAudioContext)(),
		bs = ac.createBufferSource(),
		sp = ac.createScriptProcessor(1024, 0, 2);	// (44100Hz / 1024samples) = 43.7Hz is close enough to 50Hz
		if (!ac || !bs || !sp) {
			return
		}
		this.ac = ac;
		this.sp = sp;
		sp.pulseWidth = this.pulseWidth;
		sp.pulsePolarityNegative = this.pulsePolarityNegative;
		ac.samplingRate = 44100;
		sp.onaudioprocess = function(ape) {
			var b = ape.outputBuffer;
			d0 = b.getChannelData(0),
			d1 = b.getChannelData(1),
			pw0Lo = -1,
			pw0Hi = 1,
			pw1Lo = -1,
			pw1Hi = 1;
			
			if (this.pulsePolarityNegative[0]) {
				pw0Lo = 1;
				pw0Hi = -1;
			}
			if (this.pulsePolarityNegative[1]) {
				pw1Lo = 1;
				pw1Hi = -1;
			}
			
			//
			// Thank you for reading my dirty source code. You are now reaching the GlueMotor's core part. 
			// Rest of the code are pretty obvious, but the next block is only the part that may be considered as "invention",
			// that I have came up with when I was thinking about how to improve the PWM resolution, and here is how I have solved!
			// Just in case if you feel something from this idea and want to poke me: email:support@gluemotor.com, twitter:@gluemotor
			//
			var fPW0 = this.pulseWidth[0] * 44100,
			fPW1 = this.pulseWidth[1] * 44100,
			iPW0 = Math.floor(fPW0),
			iPW1 = Math.floor(fPW1),
			fallEdge0 = pw0Lo + (pw0Hi - pw0Lo) * (fPW0 - iPW0),
			fallEdge1 = pw1Lo + (pw1Hi - pw1Lo) * (fPW1 - iPW1),
			i;
			
			if ((iPW0 > 0 && d0[iPW0 - 1] != pw0Hi) || d0[iPW0].toFixed(3) != fallEdge0.toFixed(3) || d0[iPW0 + 1] != pw0Lo) {
				for (i = 0; i < iPW0; i++) {
					d0[i] = pw0Hi
				}
				d0[i] = fallEdge0;
				for (i++; i < 1024 && d0[i] != pw0Lo; i++) {
					d0[i] = pw0Lo
				}
			}
			
			iPW1 += 512;
			if ((iPW1 > 512 && d1[iPW1 - 1] != pw1Hi) || d1[iPW1].toFixed(3) != fallEdge1.toFixed(3) || d1[iPW1 + 1] != pw1Lo) {
				if (d1[0] != pw1Lo) {
					for (i = 0; i < 512; i++) {
						d1[i] = pw1Lo
					}
				}
				for (i = 512; i < iPW1; i++) {
					d1[i] = pw1Hi
				}
				d1[i] = fallEdge1;
				for (i++; i < 1024 && d1[i] != pw1Lo; i++) {
					d1[i] = pw1Lo
				}
			}
		}
		bs.connect(sp);
		sp.connect(ac.destination);
		bs.start(0);
	},
	disable: function() {
		if (this.ac) {
			this.ac.close()
		}
		this.ac = null;
		this.sp = null;
	}
}


