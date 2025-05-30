require 'time'

def startScreen
    if File.exist?("pass")
        settings = File.open("settings", "r+")
        settings.rewind
    
        masterPassword = settings.gets

        tryTimer = Time.parse(settings.gets)
        remainingTime = tryTimer - Time.now
        puts tryTimer
        puts remainingTime

        if remainingTime <= 0
            failCount = 0
            while failCount < 5
                puts "Please enter the Master Password:"
                password = gets
                if password == masterPassword
                    puts "correct"
                    break
                else
                    puts "incorrect"
                    failCount += 1
                end
            end

            if failCount >= 5
                puts "You have tried too many times. You can try again in 20 minutes."
                settings.rewind
                settings.gets
                tryTimerReset(settings)
            end
        else
            puts "Sorry. You'll have to try again later."
            puts "Remaining time: #{remainingTime}s"
        end
    else
        newFile = File.new("pass", "w+")

        settings = File.new("settings", "w")
        puts "Please enter a Master Password:"
        masterPassword = gets
        settings.puts(masterPassword)
        settings.puts(Time.now)
        settings.close

        newFile.close
    end
end

def tryTimerReset(file)
    endTime = Time.now + 20*60

    puts Time.now
    puts endTime

    file.puts(endTime)
    file.close
end
startScreen