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