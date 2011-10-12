require "ruby-debug"

# mixin non destructive
def mixinND(targetObj, overWriteObj)
  output = Marshal.load(Marshal.dump(targetObj))
  if targetObj.instance_of?(Hash)
    overWriteObj.each_key { |key|    
      overWriteObj[key] = mixinND(targetObj[key], overWriteObj[key])
      output[key] = overWriteObj[key]
    }
  else
    output = overWriteObj
  end
  return output
end

class Numeric
  def roundoff(d=0)
    x = 10**d
    if self < 0
      (self * x - 0.5).ceil.quo(x)
    else
      (self * x + 0.5).floor.quo(x)
    end
  end
end