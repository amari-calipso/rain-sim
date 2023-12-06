package opal:   import *;
package pygame: import mixer;
package random: import randint, uniform;
import numpy, colorednoise;

new Vector RESOLUTION = Vector(1280, 720);

new int DROP_QTY          = 500,
        MIN_DROP_LEN      = 5,
        MAX_DROP_LEN      = 30,
        MIN_DROP_SIZE     = 1,
        MAX_DROP_SIZE     = 3,
        MIN_OFFSCREEN     = 100,
        MAX_OFFSCREEN     = 1000,
        MIN_Z             = 0,
        MAX_Z             = 20,
        MIN_SPEED         = 4,
        MAX_SPEED         = 10,
        ALPHA_CHANGE      = 100,
        PARTICLE_SIZE     = 1,
        LIFESPAN_DECREASE = 3,
        MIN_PARTICLE_QTY  = 5,
        MAX_PARTICLE_QTY  = 15,
        SAMPLING_RATE     = 48000;

new float PARTICLE_VELOCITY_MULTIPLIER = 0.98,
          PARTICLE_MAX_INIT_VELOCITY   = 5,
          MIN_GRAVITY                  = 0.08,
          MAX_GRAVITY                  = 0.2,
          WIND_FORCE_X                 = 0.5,
          WIND_FORCE_Y                 = 0.03,
          SPLASH_DURATION              = 0.1,
          MIN_BROWN_AMP                = 100,
          MAX_BROWN_AMP                = 2000,
          MIN_PINK_AMP                 = 50,
          MAX_PINK_AMP                 = 1000;

new tuple RAIN_COLOR = (196, 211, 255),
          BG         = (100, 100, 120);

new Vector GRAVITY = Vector(0, 0.2);

new Graphics graphics; 
main {
    graphics = Graphics(RESOLUTION, caption = "Rain");
    new int AUDIOCHS = graphics.getAudioChs()[2];
}

new class Particle {
    new method __init__(pos) {
        this.pos          = pos;
        this.acceleration = Vector();

        this.velocity = Vector(uniform(-1, 1), uniform(-1, 0));
        this.velocity *= uniform(1, PARTICLE_MAX_INIT_VELOCITY);

        this.lifeSpan = 255;
        this.alive    = True;
    }

    new method applyForce(f) {
        this.acceleration += f;
    }

    new method update() {
        this.velocity *= PARTICLE_VELOCITY_MULTIPLIER;
        this.lifeSpan -= LIFESPAN_DECREASE;

        this.velocity += this.acceleration;
        this.pos      += this.velocity;

        this.acceleration *= 0;

        if this.pos.y >= RESOLUTION.y or this.pos.x < 0 or this.pos.x >= RESOLUTION.x {
            this.alive = False;
        }
    }

    new method isAlive() {
        return this.lifeSpan >= 0 and this.alive;
    }

    new method show() {
        graphics.circle(this.pos, PARTICLE_SIZE, RAIN_COLOR, this.lifeSpan);
    }
}

new class Explosion {
    new method __init__(pos) {
        this.pos = pos;
        this.particles = [];
    }

    new method explode(pos = None) {
        if pos is not None {
            this.pos = pos;
        }

        new dynamic dur0 = int(SAMPLING_RATE * (SPLASH_DURATION + uniform(0, SPLASH_DURATION))),
                    dur1 = int(SAMPLING_RATE * (SPLASH_DURATION + uniform(0, SPLASH_DURATION))),
                    durM = max(dur0, dur1);

        new dynamic wave = (
            numpy.concatenate((colorednoise.powerlaw_psd_gaussian(1, dur0) * uniform( MIN_PINK_AMP,  MAX_PINK_AMP), numpy.zeros(durM - dur0))) + 
            numpy.concatenate((colorednoise.powerlaw_psd_gaussian(2, dur1) * uniform(MIN_BROWN_AMP, MAX_BROWN_AMP), numpy.zeros(durM - dur1)))
        );

        if AUDIOCHS > 1 {
            wave = numpy.repeat(wave.reshape(wave.size, 1), AUDIOCHS, axis = 1).astype(numpy.int16);
        } else {
            wave = wave.astype(numpy.int16);
        }

        graphics.playWaveforms([wave]);

        repeat randint(MIN_PARTICLE_QTY, MAX_PARTICLE_QTY) {
            this.particles.append(Particle(this.pos));
        }
    }

    new method update() {
        for particle in this.particles {
            particle.applyForce(GRAVITY);
            particle.update();
        }

        this.particles = [particle for particle in this.particles if particle.isAlive()];
    }

    new method isAlive() {
        return len(this.particles) > 0;
    }

    new method show() {
        for particle in this.particles {
            particle.show();
        }
    }
}

new class Drop {
    new method __init__() {
        this.__reset();
        this.explosion = Explosion(this.pos);
    }

    new method __reset() {
        this.pos = Vector(randint(0, RESOLUTION.x), randint(-MAX_OFFSCREEN, -MIN_OFFSCREEN));

        this.z         = randint(MIN_Z, MAX_Z);
        this.len       = Utils.translate(this.z, MIN_Z, MAX_Z, MAX_DROP_LEN, MIN_DROP_LEN);
        this.gravity   = Utils.translate(this.z, MIN_Z, MAX_Z,  MIN_GRAVITY,  MAX_GRAVITY);
        this.speed     = Vector(0, Utils.translate(this.z, MIN_Z, MAX_Z, MIN_SPEED, MAX_SPEED));
        this.thickness = round(Utils.translate(this.z, MIN_Z, MAX_Z, MAX_DROP_SIZE, MIN_DROP_SIZE));
    }

    new method applyForce(f) {
        this.speed += f;
    }

    new method update() {
        if this.explosion.isAlive() {
            this.explosion.update();
            this.explosion.show();
        } else {
            this.pos     += this.speed;
            this.speed.y += this.gravity;

            if this.pos.y >= RESOLUTION.y - this.speed.y {
                this.explosion.explode(Vector(this.pos.x, RESOLUTION.y));
                this.__reset();
            }

            this.pos.x = Utils.limitToRange(this.pos.x, 0, RESOLUTION.x, True);

            graphics.line(this.pos, this.pos + this.speed.magnitude(this.len), RAIN_COLOR, this.thickness);
        }
    }
}

new list drops = [Drop() for _ in range(DROP_QTY)];

@graphics.update;
new function draw() {
    new dynamic wind;
    wind = Vector(uniform(-WIND_FORCE_X, WIND_FORCE_X), uniform(0, WIND_FORCE_Y));

    for drop in drops {
        drop.applyForce(wind);
        drop.update();
    }

    graphics.fillAlpha(BG, ALPHA_CHANGE);
}

main {
    graphics.fill(BG);
    graphics.run(drawBackground = False);
}
