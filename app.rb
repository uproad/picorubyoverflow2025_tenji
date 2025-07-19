require "pwm"
require "adc"

l=GPIO.new(25,2)

p0=PWM.new(0, frequency:25000, duty:7.5)
p2=PWM.new(2, frequency:25000, duty:7.5)
p4=PWM.new(4, frequency:25000, duty:7.5)

p0.duty(0)
p2.duty(0)
p4.duty(0)

a26=ADC.new(26)
a27=ADC.new(27)
a28=ADC.new(28)

m=100
i=0

loop do
    v26 = a26.read
    v27 = a27.read
    v28 = a28.read

    d26=v26/3.3*100
    d27=v27/3.3*100
    d28=v28/3.3*100

    p0.duty(d26)
    p2.duty(d27)
    p4.duty(d28)

    if i < m/2
      l.write(1) 
    else
        l.write(0)
    end

    i = i+1
    i=0 if i >= m
    sleep(0.01)
end

