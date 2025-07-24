require 'time'
require 'openssl'
require 'base64'
require 'json'

def startScreen
    key, iv = decryptionTest(true, "none", "", "")

    if !key.nil?
        settingsName = decryptionTest(false, "settings", key, iv)
        if settingsName.nil?
            puts "ERROR 001"
            puts "Crucial file missing! Cannot continue"
            exit(1)
        end

        settings = File.open(settingsName, "r+")
        settings.rewind
        settings.gets
        settings.gets

        tryTimer = Time.parse(settings.gets)
        remainingTime = tryTimer - Time.now

        if remainingTime <= 0
            masterPassword = settings.gets
            
            failCount = 0
            while failCount < 5
                puts "Please enter the Master Password:"
                password = gets
                if password == masterPassword
                    puts "Correct"
                    viewPasswords(key, iv)
                    break
                else
                    puts "Incorrect"
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
        
        cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        cipher.encrypt
        key = cipher.random_key
        iv = cipher.random_iv

        newFile = File.new(base64_urlsafe_encode(cipher.update("pass".to_json) + cipher.final), "w+")

        cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv
        settings = File.new(base64_urlsafe_encode(cipher.update("settings".to_json) + cipher.final), "w")
        puts "Please enter a Master Password:"
        masterPassword = gets

        settings.puts(base64_urlsafe_encode(key))
        settings.puts(base64_urlsafe_encode(iv))
        settings.puts(Time.now)
        settings.puts(masterPassword)
        settings.close

        newFile.close

        viewPasswords(key, iv)
    end
end

def tryTimerReset(file)
    endTime = Time.now + 20*60

    file.rewind
    file.puts(endTime)
    file.close
end

def viewPasswords(key, iv)
    pass = decryptionTest(false, "pass", key, iv)
    storedPasswords = File.readlines(pass)
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

def decryptionTest(wantKey, wantName, oldKey, oldIv)
    if wantKey
        Dir.entries(".").each do |try|
            next if try.include?(".")

            file = File.open(try, "r")
            file.rewind

            key = file.gets
            iv = file.gets

            file.close

            next if key.nil?

            iv = base64_urlsafe_decode(iv.chomp)
            key = base64_urlsafe_decode(key.chomp)

            cipherTest = OpenSSL::Cipher::AES.new(256, :CBC)
            cipherTest.decrypt
            cipherTest.key = key
            cipherTest.iv = iv

            text = JSON.parse(cipherTest.update(base64_urlsafe_decode(try).strip) + cipherTest.final)

            if text == "settings" || text == "pass"
                return key, iv
            else
                puts "ERROR 003"
                puts "Decryption failed!"
                exit(1)
            end
        end
    else
        Dir.entries(".").each do |try|
            next if try.include?(".")

            cipher = OpenSSL::Cipher::AES.new(256, :CBC)
            cipher.decrypt
            cipher.key = oldKey
            cipher.iv = oldIv

            temp = JSON.parse(cipher.update(base64_urlsafe_decode(try).strip) + cipher.final)

            if temp == wantName
                return try
            end
        end

        puts "ERROR 003"
        puts "Decryption failed!"
        exit(1)
    end

    return
end

def base64_urlsafe_encode(data)
    Base64.strict_encode64(data).tr('+/', '-_').gsub('=', '')
end
  
def base64_urlsafe_decode(str)
    padding = '=' * ((4 - str.length % 4) % 4)
    Base64.decode64(str.tr('-_', '+/') + padding)
end

startScreen