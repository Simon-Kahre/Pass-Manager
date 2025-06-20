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
                    viewPasswords
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

        viewPasswords
    end
end

def tryTimerReset(file)
    endTime = Time.now + 20*60

    file.rewind
    file.puts(endTime)
    file.close
end

def viewPasswords()
    storedPasswords = File.readlines("pass")
    storedPasswords.push("a aa A")

    passwords = {}

    storedPasswords.each do |password|
        values = password.split

        passwords[values[0]] = values[1..2]
    end

    while true
        puts("Current sites with stored passwords:")
        passwords.each do |key, value|
            puts(key + " " +  value[0] + " " + value[1])
        end

        puts("Which one would you like to access? 'exit' to exit. 'add' to add a new password.")
        choice = gets.chomp
        puts(`clear`)

        if choice == "add"
            puts("Enter site name:")
            name = gets.chomp
            puts("Enter email:")
            mail = gets.chomp
            puts("Enter password:")
            password = gets.chomp

            passwords[name] = [mail, password]
        elsif passwords.has_key?(choice)
            puts(choice + " uses:")
            puts("Email: " + passwords[choice][0])
            puts("Password: " + passwords[choice][1])
            puts
            puts("Would you like to change anyting? Type 'yes' to change")

            newChoice = gets.chomp

            if newChoice == "yes"
                puts("What would you like to change? (email/password/delete)")
                anotherChoice = gets.chomp

                if anotherChoice == "email"
                    puts("Please enter the new email:")
                    newMail = gets.chomp
                    passwords[choice][0] = newMail

                elsif anotherChoice == "password"
                    puts("Please enter the new password:")
                    newPass = gets.chomp
                    passwords[choice][1] = newPass

                elsif anotherChoice == "delete"
                    puts("Are you sure about deleting this password? Type 'DELETE' to delete")
                    confirmation = gets.chomp

                    if confirmation == "DELETE"
                        passwords.delete(choice)
                    end

                end
            end
        end

        break if choice == "exit"
    end
end

startScreen