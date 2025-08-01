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

        cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        cipher.decrypt
        cipher.key = key
        cipher.iv = iv
        puts key
        puts iv

        tryTimer = Time.parse(JSON.parse(cipher.update(base64_urlsafe_decode(settings.gets).strip) + cipher.final))
        remainingTime = tryTimer - Time.now

        if remainingTime <= 0
            cipher = OpenSSL::Cipher::AES.new(256, :CBC)
            cipher.decrypt
            cipher.key = key
            cipher.iv = iv
            masterPassword = JSON.parse(cipher.update(base64_urlsafe_decode(settings.gets).strip) + cipher.final)
            
            failCount = 0
            while failCount < 5
                puts "Please enter the Master Password:"
                password = gets
                if password == masterPassword
                    puts "Correct"
                    settings.close
                    viewPasswords(key, iv)
                    break
                else
                    puts "Incorrect"
                    failCount += 1
                end
            end

            if failCount >= 5
                puts "You have tried too many times. You can try again in 20 minutes."
                tryTimerReset(settings, key, iv)
            end
        else
            puts "Sorry. You'll have to try again later."
            puts "Remaining time: #{remainingTime}s"
        end
    else
        puts "Please enter a Master Password:"
        masterPassword = gets

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

        settings.puts(base64_urlsafe_encode(key))
        settings.puts(base64_urlsafe_encode(iv))

        cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv
        settings.puts(base64_urlsafe_encode(cipher.update(Time.now.to_json) + cipher.final))

        cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv
        settings.puts(base64_urlsafe_encode(cipher.update(masterPassword.to_json) + cipher.final))
        settings.close

        newFile.close

        puts key
        puts iv

        viewPasswords(key, iv)
    end
end

def tryTimerReset(file, key, iv)
    timeCipher = OpenSSL::Cipher::AES.new(256, :CBC)
    timeCipher.encrypt
    timeCipher.key = key
    timeCipher.iv = iv

    endTime = base64_urlsafe_encode(timeCipher.update((Time.now + 20*60).to_json) + timeCipher.final)
    #endTime = Time.now + 20*60

    file.rewind
    file.gets
    file.gets
    file.puts(endTime)
    file.close
end

def viewPasswords(key, iv)
    pass = decryptionTest(false, "pass", key, iv)
    storedPasswords = File.readlines(pass)

    passwords = {}

    storedPasswords.each do |password|
        stringCipher = OpenSSL::Cipher::AES.new(256, :CBC)
        stringCipher.decrypt
        stringCipher.key = key
        stringCipher.iv = iv

        line = JSON.parse(stringCipher.update(base64_urlsafe_decode(password).strip) + stringCipher.final)

        values = line.split

        passwords[values[0]] = values[1..2]
    end

    while true
        puts("Current sites with stored passwords:")
        passwords.each do |key, value|
            puts(key + ": " +  value[0] + " " + value[1])
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

        if choice == "exit"
            saveFiles(passwords, pass, key, iv)
        end
    end
end

def decryptionTest(wantKey, wantName, oldKey, oldIv)
    if wantKey
        Dir.entries(".").each do |try|
            next if try.include?(".")

            begin
                file = File.open(try, "r")
                file.rewind

                fKey = file.gets
                fIv = file.gets

                file.close

                next if fKey.nil?

                iv = base64_urlsafe_decode(fIv.chomp)
                key = base64_urlsafe_decode(fKey.chomp)

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
            rescue
                next
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
    puts "ERROR 002"
    puts "Decryption failed! Manual attention needed!"
    exit(1)
end

def saveFiles(passwords, passName, oldK, oldI)
    pass = File.open(passName, "w")
    pass.rewind

    cipher = OpenSSL::Cipher::AES.new(256, :CBC)
    cipher.encrypt
    key = cipher.random_key
    iv = cipher.random_iv

    passwords.each do |vKey, value|
        storeString = (vKey + " " + value[0] + " " + value[1])

        stringCipher = OpenSSL::Cipher::AES.new(256, :CBC)
        stringCipher.encrypt
        stringCipher.key = key
        stringCipher.iv = iv

        encryptedString = base64_urlsafe_encode(stringCipher.update(storeString.to_json) + stringCipher.final)
        pass.puts(encryptedString)
    end

    pass.close

    Dir.entries(".").each do |file|
        next if file.include?(".")

        cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv

        if file != passName
            settings = File.open(file, "r+")
            settings.rewind
            settings.puts(base64_urlsafe_encode(key))
            settings.puts(base64_urlsafe_encode(iv))

            cipher = OpenSSL::Cipher::AES.new(256, :CBC)
            cipher.decrypt
            cipher.key = oldK
            cipher.iv = oldI

            decodedTime = JSON.parse(cipher.update(base64_urlsafe_decode(settings.gets).strip) + cipher.final)

            cipher = OpenSSL::Cipher::AES.new(256, :CBC)
            cipher.decrypt
            cipher.key = oldK
            cipher.iv = oldI

            decodedMast = JSON.parse(cipher.update(base64_urlsafe_decode(settings.gets).strip) + cipher.final)

            cipher = OpenSSL::Cipher::AES.new(256, :CBC)
            cipher.encrypt
            cipher.key = key
            cipher.iv = iv

            settings.rewind
            settings.gets
            settings.gets

            settings.puts(base64_urlsafe_encode(cipher.update(decodedTime.to_json) + cipher.final))

            cipher = OpenSSL::Cipher::AES.new(256, :CBC)
            cipher.encrypt
            cipher.key = key
            cipher.iv = iv

            settings.puts(base64_urlsafe_encode(cipher.update(decodedMast.to_json) + cipher.final))

            cipher = OpenSSL::Cipher::AES.new(256, :CBC)
            cipher.encrypt
            cipher.key = key
            cipher.iv = iv

            settings.close

            File.rename(file, base64_urlsafe_encode(cipher.update("settings".to_json) + cipher.final))
        else
            File.rename(file, base64_urlsafe_encode(cipher.update("pass".to_json) + cipher.final))
        end
    end

    exit(0)
end

def base64_urlsafe_encode(data)
    Base64.strict_encode64(data).tr('+/', '-_').gsub('=', '')
end
  
def base64_urlsafe_decode(str)
    padding = '=' * ((4 - str.length % 4) % 4)
    Base64.decode64(str.tr('-_', '+/') + padding)
end

startScreen