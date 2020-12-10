--[[
    The following example code:

    emulates a class's namespace MyObject = {} and saves the object constructor as MyObject.new()
    hides all of the details of the objects inner workings so that a user of an object only sees a pure table 
            (see setmetatable() and __metatable)
    uses closures for information hiding (see Lua Pil 16.4 and Object Benchmark Tests)
    prevents modification of the object (see __newindex)
    allows for methods to be intercepted (see __index)
    lets you get a list of all of the functions and attributes (see the 'key' attribute in __index)
    looks, acts, walks, and talks like a normal Lua table (see __pairs, __len, __ipairs)
    looks like a string when it needs to (see __tostring)
    works with Lua 5.2
]]--

MyObject = {}
MyObject.new = function(name)
   local objectName = name

   -- A table of the attributes we want exposed
   local attrs = {
      attr1 = 123,
   }

   -- A table of the object's methods (note the comma on "end,")
   local methods = {
      method1 = function()
         print("\tmethod1")
      end,

      print = function(...)
         print("MyObject.print(): ", ...)
      end,

      -- Support the less than desirable colon syntax
      printOOP = function(self, ...)
         print("MyObject:printOOP(): ", ...)
      end,
   }

   -- Another style for adding methods to the object (I prefer the former
   -- because it's easier to copy/paste function()'s around)
   function methods.addAttr(k, v)
      attrs[k] = v
      print("\taddAttr: adding a new attr: " .. k .. "=\"" .. v .. "\"")
   end

   -- The metatable used to customize the behavior of the table returned by new()
   local mt = {
      -- Look up nonexistent keys in the attrs table. Create a special case for the 'keys' index
      __index = function(t, k)
         v = rawget(attrs, k)
         if v then
            print("INFO: Successfully found a value for key \"" .. k .. "\"")
            return v
         end
         -- 'keys' is a union of the methods and attrs
         if k == 'keys' then
            local ks = {}
            for k,v in next, attrs, nil do
               ks[k] = 'attr'
            end
            for k,v in next, methods, nil do
               ks[k] = 'func'
            end
            return ks
         else
            print("WARN: Looking up nonexistant key \"" .. k .. "\"")
         end
      end,

      __ipairs = function()
         local function iter(a, i)
            i = i + 1
            local v = a[i]
            if v then
               return i, v
            end
         end
         return iter, attrs, 0
      end,

      __len = function(t)
         local count = 0
         for _ in pairs(attrs) do count = count + 1 end
         return count
      end,

      __metatable = {},

      __newindex = function(t, k, v)
         if rawget(attrs, k) then
            print("INFO: Successfully set " .. k .. "=\"" .. v .. "\"")
            rawset(attrs, k, v)
         else
            print("ERROR: Ignoring new key/value pair " .. k .. "=\"" .. v .. "\"")
         end
      end,

      __pairs = function(t, k, v) return next, attrs, nil end,

      __tostring = function(t) return objectName .. "[" .. tostring(#t) .. "]" end,
   }
   setmetatable(methods, mt)
   return methods
end
----------------------------------------------------------------------------------------------------------------------------
-- Create the object
local obj = MyObject.new("my object's name")

print("Iterating over all indexes in obj:")
for k,v in pairs(obj) do print('', k, v) end
print()

print("obj has a visibly empty metatable because of the empty __metatable:")
for k,v in pairs(getmetatable(obj)) do print('', k, v) end
print()

print("Accessing a valid attribute")
obj.print(obj.attr1)
obj.attr1 = 72
obj.print(obj.attr1)
print()

print("Accessing and setting unknown indexes:")
print(obj.asdf)
obj.qwer = 123
print(obj.qwer)
print()

print("Use the print and printOOP methods:")
obj.print("Length: " .. #obj)
obj:printOOP("Length: " .. #obj) -- Despite being a PITA, this nasty calling convention is still supported

print("Iterate over all 'keys':")
for k,v in pairs(obj.keys) do print('', k, v) end
print()

print("Number of attributes: " .. #obj)
obj.addAttr("goosfraba", "Satoshi Nakamoto")
print("Number of attributes: " .. #obj)
print()

print("Iterate over all keys a second time:")
for k,v in pairs(obj.keys) do print('', k, v) end
print()

obj.addAttr(1, "value 1 for ipairs to iterate over")
obj.addAttr(2, "value 2 for ipairs to iterate over")
obj.addAttr(3, "value 3 for ipairs to iterate over")
obj.print("ipairs:")
for k,v in ipairs(obj) do print(k, v) end

print("Number of attributes: " .. #obj)

print("The object as a string:", obj)

--[[  OUTPUT: 
    Iterating over all indexes in obj:
    attr1   123

obj has a visibly empty metatable because of the empty __metatable:

Accessing a valid attribute
INFO: Successfully found a value for key "attr1"
MyObject.print():   123
INFO: Successfully set attr1="72"
INFO: Successfully found a value for key "attr1"
MyObject.print():   72

Accessing and setting unknown indexes:
WARN: Looking up nonexistant key "asdf"
nil
ERROR: Ignoring new key/value pair qwer="123"
WARN: Looking up nonexistant key "qwer"
nil

Use the print and printOOP methods:
MyObject.print():   Length: 1
MyObject.printOOP():        Length: 1
Iterate over all 'keys':
    addAttr func
    method1 func
    print   func
    attr1   attr
    printOOP        func

Number of attributes: 1
    addAttr: adding a new attr: goosfraba="Satoshi Nakamoto"
Number of attributes: 2

Iterate over all keys a second time:
    addAttr func
    method1 func
    print   func
    printOOP        func
    goosfraba       attr
    attr1   attr

    addAttr: adding a new attr: 1="value 1 for ipairs to iterate over"
    addAttr: adding a new attr: 2="value 2 for ipairs to iterate over"
    addAttr: adding a new attr: 3="value 3 for ipairs to iterate over"
MyObject.print():   ipairs:
1   value 1 for ipairs to iterate over
2   value 2 for ipairs to iterate over
3   value 3 for ipairs to iterate over
Number of attributes: 5
The object as a string: my object's name[5]
]]