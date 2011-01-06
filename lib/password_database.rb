require 'sqlite3'

class PasswordDatabase < SQLite3::Database
  def initialize(file_name, key)
    super(file_name)
    set_key(key)
  end

  def set_key(key)
    execute("PRAGMA key='#{key}';")
  end
  def set_cipher(cipher)
    execute("PRAGMA cipher='#{cipher}';")
  end
  def set_kdf_iterations(iterations)
    execute("PRAGMA kdf_iter='#{iterations}';")
  end
  def set_rekey(key)
    execute("PRAGMA rekey='#{key}';")
  end
  def set_rekey_cipher(cipher)
    execute("PRAGMA rekey_cipher='#{cipher}';")
  end
  def set_rekey_kdf_iterations(iterations)
    execute("PRAGMA rekey_kdf_iter='#{iterations}';")
  end
  def rekey(key, cipher=nil, iterations=nil)
    if(cipher)
      set_rekey_cipher(cipher)
    end
    if(iterations)
      set_rekey_kdf_iterations(iterations)
    end
    set_rekey(key)
  end

  def unlocked?
    return false if closed?

    begin
      result = get_first_value("SELECT COUNT(*) FROM sqlite_master;")
    rescue Exception => e
      puts "[SQLite] #{e.message}"
      return false
    end
    return false unless result
    
    return true
  end
end
