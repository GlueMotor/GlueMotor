//
//  GlueMotorCore.js
//  GlueMotorCore
//
//  Created by Kazuhisa "Kazu" Terasaki on 11/20/2016.
//  Copyright © 2016 Kazuhisa Terasaki All rights reserved.
//  https://github.com/gluemotor
//

var glueMotorCore = {
	// parameter:
	//	pulseWidth: pulseWidth in seconds (e.g. center position is 0.0015)
	//	servoIndex: should be 0 (L-channel) or 1 (R-channel)
	setPulseWidth: function(pulseWidth, servoIndex) {
		if (this.sp) {
			this.sp.pulseWidth[servoIndex] = pulseWidth
		}
	},
	enable: function() {
		if (this.ac) {
			return
		}
		var ac = new (window.AudioContext || window.webkitAudioContext)(),
		bs = ac.createBufferSource(),
		sp = ac.createScriptProcessor(1024, 0, 2);
		if (!ac || !bs || !sp) {
			return
		}
		this.ac = ac;
		this.sp = sp;
		sp.pulseWidth = [0, 0];
		ac.samplingRate = 44100;
		sp.onaudioprocess = function(ape) {
			var b = ape.outputBuffer;
			d0 = b.getChannelData(0),
			d1 = b.getChannelData(1),
			v0 = 1,
			v1 = 1;
			
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
			fallEdge0 = -1 + 2 * (fPW0 - iPW0),
			fallEdge1 = -1 + 2 * (fPW1 - iPW1);
			
			for (var c = 0; c < b.length; c++) {
				if (c == iPW0) {
					v0 = -1;
					d0[c] = fallEdge0;
				} else {
					d0[c] = v0;
				}
				if (c == iPW1) {
					v1 = -1
					d1[c] = fallEdge1;
				} else {
					d1[c] = v1;
				}
			}
		}
		bs.connect(sp);
		sp.connect(ac.destination);
		bs.start(0);
	},
	disable: function() {
		this.ac.close();
		this.ac = null;
		this.sp = null;
	}
}


