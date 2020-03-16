require "time"

class Bar
  @netstate = Hash(String, Tuple(Int64, Int64)).new do |hash, key|
    hash[key] = {0_i64, 0_i64}
  end

  @now : Time::Span
  @previous : Time::Span
  @proc_net_dev : String

  def initialize
    @now = Time.monotonic
    @previous = @now
    @proc_net_dev = ""
  end

  def show
    @previous = @now
    @now = Time.monotonic
    @proc_net_dev = File.read "/proc/net/dev"
    join_bar unread_mails, mic, wired, wifi, temperature, battery, datetime
  end

  private def unread_mails
    unread = `notmuch count tag:unread AND tag:inbox AND NOT tag:feed`.to_i
    return if unread.zero?
    "\u{1F582} #{unread}"
  end

  private def temperature
    temp = `sensors`.lines[2].gsub(/.*?\+(.*?)\..*/, "\\1").to_i
    "#{temp}℃"
  end

  private def wifi
    current_ssid = ssid
    info = net_info "wlp"
    if info.nil? || current_ssid.empty?
      "\u{1F4E1} \u{2205}"
    else
      rx, tx, ip = info
      "\u{1F4E1}#{current_ssid} #{ip} #{traffic rx, tx}"
    end
  end

  private def wired
    info = net_info "enp"
    if info.nil?
      "\u{1F5A7} \u{2205}"
    else
      rx, tx, ip = info
      "\u{1F5A7} #{ip} #{traffic rx, tx}"
    end
  end

  private def datetime
    Time.now.to_s("%a %d %b, %H:%M ")
  end

  private def battery
    battery_info = `acpi -b`.strip
    percent = battery_info.gsub(/.*?(\d+%).*/, "\\1")
    symbol = battery_info.includes?("Discharging") ? "🔋" : "🔌"
    "#{symbol} #{percent}"
  end

  private def mic
    pulse_sources = `pactl list sources`
    if pulse_sources.includes?("Mute: yes")
      "\u{1F399} \u{274C}"
    else
      "\u{1F399} \u{23FA}"
    end
  end

  private def join_bar(*items)
    items.select{ |i| !i.nil? && !i.empty? }.join(" | ")
  end

  private def net_info(prefix)
    line = @proc_net_dev.lines.find { |l| l.strip.starts_with?(prefix) }
    return if line.nil?
    columns = line.split
    dev = columns[0].strip[0..-2]
    ip = ip_for_device dev

    crx = columns[1].to_i64
    ctx = columns[9].to_i64

    prx, ptx = @netstate[prefix]
    @netstate[prefix] = {crx, ctx}

    drx = crx - prx
    dtx = ctx - ptx

    dt = (@now - @previous).total_nanoseconds.to_i64
    rx = (drx * 1_000_000_000) / dt
    tx = (dtx * 1_000_000_000) / dt

    {rx, tx, ip}
  end

  private def ip_for_device(dev)
    `ip addr show #{dev}`.lines
                         .find { |l| l.strip.starts_with?("inet ") }
                         .try { |l| l.split[1] }
  end

  private def traffic(rx, tx)
    ratio = rx.to_f / tx.to_f
    ratio = 1.0 if ratio.nan?
    symbol = if 10.0 > ratio > 0.1
      "\u{2B0D}"
    elsif ratio > 1.0
      "\u{2B07}"
    else
      "\u{2B06}"
    end
    "#{symbol} #{(rx + tx).humanize_bytes.rjust(7)}/s"
  end

  private def ssid
    link_info = `iw dev wlp58s0 link`
    if link_info.starts_with?("Connected")
      " #{link_info.lines[1].strip[6..-1]}"
    else
      ""
    end
  end
end



bar = Bar.new
loop do
  `xsetroot -name \" #{bar.show}\"`
  sleep 1
end
