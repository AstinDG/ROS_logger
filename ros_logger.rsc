# SETUP
# WARNING! The scheduled script run interval should be in the range from 5 to 60 minutes.
:local scheduleName "telegram_notifier"
# Telegram bot token
:local botToken ""
# Telegram chat id
:local chatId ""
# Keywords for logging
:local foundLogs [:toarray [/log find message~"logged" || message~"tp-out1: terminating" || message~"tp-out1: connected" || topics~"critical" || message~"link" || message~"connected" || message~"disconnected"]]
# Messages then will be marked as "OK"
:local resolvedMessages {"link up";": connected"; "wlan1 connected,"; "wlan2 connected,"; "ntp change time"}
# Messges that contains MAC address for search at DHCP->leases
:local wifiKeyword "wlan"
# Messages that match the keyword but should be ignored
:local ignoreMessages {"192.168.88."}
# END SETUP


# check internet access
:if ([/ping 1.1.1.1 count=1] < 1 || [/ping 8.8.8.8 count=1] < 1) do={
  /log error "[TLG] no internet access"
  :error 
}

# check telegram api access
:if ([/ping api.telegram.org count=2] < 1) do={
  /log error "[TLG] no access to Telegram API"
  :error
}

# check for the presence of the desired name in the scheduler
:if ([:len [/system scheduler find name="$scheduleName"]] = 0) do={
  /log error "[TLG] ERROR: Schedule does not exist. Create schedule and edit script to match name"
  :error
}

# check if router was rebooted
:local uptime [/system resource get uptime]
#interval plus 1 minute of loading the router. required to send notification 
:local interval ([/system scheduler get [find name="$scheduleName"] interval] + [:totime "00:01:00"])
:if ($uptime < $interval) do={
  :local model [/system routerboard get board-name]
  :local rebootText ("%E2%9A%a0%EF%B8%8F MikroTik ".$model." rebooted %E2%9A%a0%EF%B8%8F %0A%0Auptime: ".$uptime)
  :local url ("https://api.telegram.org/bot".$botToken."/sendMessage\?chat_id=".$chatId."&text=".$rebootText)
  /tool fetch url="$url" dst-path=telegramLog.txt;
}

# TODO check ntp client is enabled


:local lastRunTime [/system scheduler get [find name="$scheduleName"] comment]

# for checking time of each log entry
:local currentTime
:local getCurrentTime do={
  
#   LOG DATE
#   depending on log date/time, the format may be different. 3 known formats
#   format of jan/01/2002 00:00:00 which shows up at unknown date/time. Using as default
#   format of 00:00:00 which shows up on current day's logs
   :if ([:len $time] = 8 ) do={
      # log time after the current time means that this log was recorded before NTP client update
      :if ( [/system clock get time] < $time ) do={
        :return ("[unknown date] ".$time)
      } else={
        :return ([:pick [/system clock get date] 0 11]." ".$time)
      }
    } else={
#     format of jan/01 00:00:00 which shows up on previous day's logs
     :if ([:len $time] = 15 ) do={
        :return ([:pick $time 0 6]."/".[:pick [/system clock get date] 7 11]." ".[:pick $time 7 15])
      } else={
        :return $time
      }
   }
}

:local getCommentDhcpLease  do={
  :local mac [:pick $message 0 17]
  :return [/ip dhcp-server lease get [find mac-address=$mac] comment ]
}

# log message
:local message

# output
:local output
local counter
:local keepOutput false
:if ([:len $lastRunTime] = 0) do={
  :set keepOutput true
}

:foreach log in=$foundLogs do={
  :set currentTime [$getCurrentTime time=[ /log get $log time ]]

  :if $keepOutput do {
    :local keepLog true

    :foreach ignore in=$ignoreMessages do={
    #   if this log entry contains any of them, it will be ignored
      :if ([/log get $log message] ~ "$ignore") do={
        :set keepLog false
      }
    }

    :if $keepLog do={
      :set message [/log get $log message]
      :if ($message ~ $wifiKeyword) do={
        :local comment [$getCommentDhcpLease message=$message]
        :if ([:len $comment] > 0) do={
          :set message ($message." [".$comment."]")
        }
      }

      # Resolved messages
      :local resolvedMessage false
      foreach resolved in=$resolvedMessages do={
        :if ([/log get $log message] ~ "$resolved") do={
          :set resolvedMessage true
        }
      }

      #   if keepOutput is true, add this log entry to output      
      :if $resolvedMessage do={
        :set output ($output."%E2%9C%85 OK %E2%9C%85 %0ATIME: ".$currentTime."%0AMESSAGE: ".$message."%0A%0A")
      } else={
        :set output ($output."%F0%9F%98%B1 WARNING %F0%9F%98%B1 %0ATIME: ".$currentTime."%0AMESSAGE: ".$message."%0A%0A")
      }
    }
  }

  :if ($currentTime = $lastRunTime) do={
     :set keepOutput true
     :set output ""
  }

  
  :if ($counter = ([:len $foundLogs]-1)) do={
#   If keepOutput is still false after loop, this means lastTime has a value, but a matching currentTime was never found.
#   This can happen if 1) The router was rebooted and matching logs stored in memory were wiped, or 2) An item is added
#   to the removeThese array that then ignores the last log that determined the lastTime variable.
#   This resets the comment to nothing. The next run will be like the first time, and you will get all matching logs
    :if (!$keepOutput) do={
      /system scheduler set [find name="$scheduleName"] comment=""
    }
    
  }
  set counter ($counter + 1)
  
}

# send to telegram and save current time
if ([:len $output] > 0) do={
  /system scheduler set [find name="$scheduleName"] comment=$currentTime
  :local url ("https://api.telegram.org/bot".$botToken."/sendMessage\?chat_id=".$chatId."&text=".$output)
  /tool fetch url="$url" dst-path=telegramLog.txt;
  /log info "[LOG-TLG] New logs found, send Telegram"
}