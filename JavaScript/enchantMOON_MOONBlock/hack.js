//
//  hack.js
//  GlueMotor Demo on MOONBlock
//
//  Created by Kazuhisa "Kazu" Terasaki on 1/12/2015.
//  Copyright © 2015-2016 Kazuhisa Terasaki All rights reserved.
//  https://github.com/gluemotor
//

importJS(["lib/stickerlib.min.js"], function() {
    enchant();
    enchant.puppet.prepareTheatre({
        assets: ["chara1.png"],
        eventSource: ["enchantgluemotorv1"]
    });
    StickerPuppet.create("TelepathyGlueMotor", {
        behavior: [{
            stickertap: function(event) {},
            stickerattach: function(event) {
                alert("Visit gluemotor.com for more info.");
                enchant.puppet.stopTheatre();
            },
            stickerdetach: function(event) {
                enchant.puppet.stopTheatre();
            }
        }]
    });
    Puppet.create("Bear", {
        filename: "chara1.png",
        w: 32,
        h: 32,
        behavior: ["standAlone",
        {
            sceneStart: function() {
                this.interval = 30;
                this.initialNumber = 10;
            }
        }, {
            init: function(event) {
                window.bear = this;
            }
        }, "tapChase",
        {
            sceneTouchend: function(event) {
                var i = enchant.puppet.Theatre.instance;
                this.xy = (event.x / i.width) + "," + (event.y / i.height);
                enchant.puppet.Theatre.instance.sendTelepathy("enchantgluemotorv1", this.xy || null);
            }
        }, {
            init: function() {
                enchant.puppet.Theatre.instance.addChanneler("enchantgluemotorv1", this);
            },
            telepathy_enchantgluemotorv1: function() {
                if ((window.enchant.puppet.Theatre.instance.telepathySense.lastTelepathy.data != this.xy)) {
                    var i = enchant.puppet.Theatre.instance;
                    var a = i.telepathySense.lastTelepathy.data.split(",");
                    i.touchX = parseFloat(a[0]) * i.width;
                    i.touchY = parseFloat(a[1]) * i.height;
                } else {

                }
            },
            actordie: function() {
                enchant.puppet.Theatre.instance.removeChanneler("enchantgluemotorv1", this);
            }
        }]
    });
    SignBoard.create("Text", {
        w: 0,
        h: 30,
        t: "",
        f: "24px monospace",
        color: "#ffffff",
        behavior: ["standAlone",
        {
            sceneStart: function() {
                this.startPin = [
                    [0, 0]
                ];
            }
        }, {
            init: function(event) {
                if (window.AudioContext || window.webkitAudioContext) {
                    this.text = "Start GlueMoto";
                } else {
                    this.die();
                }
            }
        }, {
            touchend: function(event) {
                if (!this.ac) {
                    var ac = new(window.AudioContext || window.webkitAudioContext)(),
                        bs = ac.createBufferSource(),
                        sp = ac.createScriptProcessor(1024, 0, 2);
                    this.ac = ac;
                    ac.samplingRate = 44100;
                    sp.onaudioprocess = function(ape) {
                        var b = ape.outputBuffer,
                            d0 = b.getChannelData(0),
                            d1 = b.getChannelData(1),
                            i = enchant.puppet.Theatre.instance,
                            x = Math.round(44.1 + window.bear.x * 44.1 / i.width),
                            y = Math.round(44.1 + window.bear.y * 44.1 / i.height),
                            v0 = 1,
                            v1 = 1;
                        for (var c = 0; c < b.length; c++) {
                            if (c == x) {
                                v0 = -1
                            }
                            if (c == y) {
                                v1 = -1
                            }
                            d0[c] = v0;
                            d1[c] = v1;
                        }
                    }
                    bs.connect(sp);
                    sp.connect(ac.destination);
                    bs.start(0);
                    this.die();
                }
            }
        }]
    });
});