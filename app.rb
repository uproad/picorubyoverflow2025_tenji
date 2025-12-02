require "pwm"
require "adc"

# アナログ入力のpeak to peakを取るためのサンプル保存数
# 20あれば音声信号の山を数周分ぐらい取れてる
# 20以上増やすとminmaxメソッドの処理時間が長すぎて動作ループが目視できてしまう
# つまりこれが最適
m=20

# ウォッチドックLED用設定
wd_cyc = 0
wd_res = 5

# アナログ入力値保存配列
d26 = Array.new(m, 0)
d27 = Array.new(m, 0)
d28 = Array.new(m, 0)

# ウォッチドックLED（基盤実装LED）
l=GPIO.new(25,2)

f=100000
duty=10000

# PWM出力端子(LED制御用)
p6=PWM.new(6, frequency: f, duty: duty)
p7=PWM.new(7, frequency: f, duty: duty)
p8=PWM.new(8, frequency: f, duty: duty)

p6.duty(0)
p7.duty(0)
p8.duty(0)

# peak to peakの最大値保存変数
m26 = 0.1
m27 = 0.1
m28 = 0.1

# peak to peakの最小値保存変数
b26 = 3.3
b27 = 3.3
b28 = 3.3

# アナログ入力端子
a26=ADC.new(26)
a27=ADC.new(27)
a28=ADC.new(28)

i=0

loop do
    # アナログ入力を読み取る
    d26[i] = a26.read
    d27[i] = a27.read
    d28[i] = a28.read

    # d配列のminmaxを取ることでpeak to peakとなる
    pp26 = d26.minmax
    pp27 = d27.minmax
    pp28 = d28.minmax

    # アナログ端子のread値は電圧の生の値なので3.3Vで割って0.0～1.0に補正
    x26=(pp26[1] - pp26[0])/3.3
    x27=(pp27[1] - pp27[0])/3.3
    x28=(pp28[1] - pp28[0])/3.3

    # 信号レベルが低すぎる場合には補正
    # multi = 50.0
    # x26 = x26  * multi * 10
    # x27 = x27  * multi * 6
    # x28 = x28  * multi

    # 動作中のpeak to peakの信号差の最大値を保存して最大点灯の目安にする
    m26 = x26 if m26 < x26
    m27 = x27 if m27 < x27
    m28 = x28 if m28 < x28

    # peak to peakの信号差の最小値を保存（これは多分ノイズ成分）こっちは完全消灯の目安
    b26 = x26 if b26 > x26
    b27 = x27 if b27 > x27
    b28 = x28 if b28 > x28

    # ノイズ成分を除去し、直近の最大信号差からどれだけ低いかを抽出。これが点灯レベルの基本の値となる
    x26 = (x26 - b26)/m26
    x27 = (x27 - b27)/m27
    x28 = (x28 - b28)/m28

    # 一旦0.0～1.1に丸め込んで扱いやすくする
    duty26 = x26.clamp(0.0, 1.0)
    duty27 = x27.clamp(0.0, 1.0)
    duty28 = x28.clamp(0.0, 1.0)

    # duty比として渡すために0～100に拡大する
    # あえて-10～110に拡大して最大/最小付近で点灯レベルが0%/100%に張り付くようにする
    duty26 = duty26 * 120 -10
    duty27 = duty27 * 120 -10
    duty28 = duty28 * 120 -10

    duty26 = duty26.clamp(0.0, 100.0)
    duty27 = duty27.clamp(0.0, 100.0)
    duty28 = duty28.clamp(0.0, 100.0)

    # 実際のPWM出力
    p6.duty(duty26)
    p7.duty(duty27)
    p8.duty(duty28)

    # デバッグ出力するならここ
    # print "   #{(pp26[1] - pp26[0]).to_s[0..4]} #{(pp27[1] - pp27[0]).to_s[0..4]} #{(pp28[1] - pp28[0]).to_s[0..4]}"
    # print "   #{x26.to_s[0..4]} #{x27.to_s[0..4]} #{x28.to_s[0..4]}"
    # print "   #{duty26.to_s[0..4]} #{duty27.to_s[0..4]} #{duty28.to_s[0..4]}"
    # puts

    # ウォッチドックLEDの点滅
    # 何らかのエラーで止まったらLEDが点滅しなくなる
    # 変数wd_xxxとmとsleepの時間から1秒で1サイクルするように調整してある
    # この変数を変えると点滅時間が変わる
    if wd_cyc < wd_res/2
      l.write(1) 
    else
      l.write(0)
    end

    i = i+1

    if i >= m
      i=0

      wd_cyc = wd_cyc + 1
      wd_cyc = 0 if wd_cyc >= wd_res

      # ちょっとづつ過去の最大値を減衰させて曲ごと/メロ-サビ間の音量差を吸収する
      # だいたいこの調整で連続再生の切れ目でリセットされる
      m26 = m26 - 0.1 if m26 > 0.5
      m27 = m27 - 0.1 if m26 > 0.5
      m28 = m28 - 0.1 if m26 > 0.5
    end

    sleep(0.01)
end
