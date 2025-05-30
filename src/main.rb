require 'time'

def startScreen
    if File.exist?("pass")
        if !File.exist?("settings")
            puts "ERROR 001"
            puts "Crucial file missing! Cannot continue"
            exit(1)
        end

        settings = File.open("settings", "r+")
        settings.rewind

        tryTimer = Time.parse(settings.gets)
        remainingTime = tryTimer - Time.now

        if remainingTime <= 0
            masterPassword = settings.gets
            
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
                tryTimerReset(settings)
            end
        else
            puts "Sorry. You'll have to try again later."
            puts "Remaining time: #{remainingTime}s"
        end
    else
        if File.exist?("settings")
            puts "ERROR 002"
            puts "Conflicting file information! Manual fix is required!"
            exit(1)
        end
        
        newFile = File.new("pass", "w+")

        settings = File.new("settings", "w")
        puts "Please enter a Master Password:"
        masterPassword = gets

        settings.puts(Time.now)
        settings.puts(masterPassword)
        settings.close

        newFile.close
    end
end

def tryTimerReset(file)
    endTime = Time.now + 20*60

    file.rewind
    file.puts(endTime)
    file.close
end
startScreen