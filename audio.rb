#!/usr/bin/env ruby

require 'tmpdir'
require 'narray' # gem narray
require 'numru/fftw3' # gem ruby-fftw3
require 'coreaudio' # gem coreaudio
require 'curses'

include Curses

# init_screen()

class NArray; include Enumerable; end

def color mag, average
  # size = average / mag
  size = mag / average

  if size >= 1
    :on_intense_red
  elsif size >= 0.9
    :on_red
  elsif size >= 0.8
    :on_intense_yellow
  elsif size >= 0.7
    :on_yellow
  elsif size >= 0.6
    :on_intense_magenta
  elsif size >= 0.5
    :on_magenta
  elsif size >= 0.4
    :on_intense_blue
  elsif size >= 0.3
    :on_blue
  elsif size >= 0.2
    :on_intense_cyan
  elsif size >= 0.1
    :on_cyan
  else
    :on_green
  end
end

audio = `sox "#{ARGV[0]}" -t raw - 2>/dev/null`.force_encoding("ascii-8bit")

video_dir = Dir.mktmpdir
system "ffmpeg", "-i", ARGV[1], "-f", "image2", "-vframes", (audio.bytesize/47040).to_s, "#{video_dir}/%05d.ppm", 1 => IO::NULL, 2 => IO::NULL

dev = CoreAudio.default_output_device
buf = dev.output_buffer(47040)
buf.start

(0..audio.bytesize/47040).each do |n|
  pos = n * 47040
  sample = audio[pos..pos+47039]

  na = NArray.to_narray(sample, NArray::SINT, 2, sample.bytesize/4)
  na_f = na.to_f

  na_complex = NumRu::FFTW3.fft(na_f,-1)
  average_mag = na_complex[0..1].map {|n| n.magnitude}.inject(0,:+)/2
  sample_mag = na_complex.map {|n| n.magnitude}.inject(0,:+)/na_complex.size

  bars = []
  (0..12).each do |n|
    pos = 1800 * n
    bars << na_complex[pos+2..pos+1801].map {|n| n.magnitude}.inject(0,:+)/1800
  end

  buf << na

  setpos(0,0)
  image_path = "%05d.ppm" % (n+1)
  image = `aview -driver stdout -height 26 "#{video_dir}"/#{image_path}`.split("\f")[1][1..-1]
  image.lines.each_slice(2).with_index do |lines, index|
    lines.each_with_index do |l,i|
      setpos(index*2+i,0)
      addstr(l.chomp)
    end
  end

  refresh()
end

buf.stop
