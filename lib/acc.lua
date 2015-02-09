require "cord"
local ACC = {}

ACCEL_CTRL_REG1 = 0x2A
ACCEL_M_CTRL_REG1 = 0x5B
ACCEL_M_CTRL_REG2 = 0x5C
ACCEL_XYZ_DATA_CFG = 0x0E
ACCEL_WHOAMI = 0x0D
ACCEL_OUT_X_MSB = 0x01
ACCEL_WHOAMI_VAL = 0xC7

ACCEL_GVALUE = 8200

function ACC:new()
   local obj = {port=storm.i2c.INT, addr = 0x3c, 
                reg=REG:new(storm.i2c.INT, 0x3c)}
   setmetatable(obj, self)
   self.__index = self
   return obj
end


function ACC:init()
    local tmp = self.reg:r(ACCEL_WHOAMI)
    assert (tmp == ACCEL_WHOAMI_VAL, "accelerometer")

    --lets put it into standby
    self.reg:w(ACCEL_CTRL_REG1, 0x00);

    --Config magnetometer
    self.reg:w(ACCEL_M_CTRL_REG1, 0x1f)
    self.reg:w(ACCEL_M_CTRL_REG2, 0x20)

    --config accelerometer
    self.reg:w(ACCEL_XYZ_DATA_CFG, 0x01)

    --go out of standby
    self.reg:w(ACCEL_CTRL_REG1, 0x0D)
end

function ACC:get()
    -- lets be efficient and read all 6 values
    local addr = storm.array.create(1, storm.array.UINT8)
    addr:set(1, ACCEL_OUT_X_MSB)
    local rv = cord.await(storm.i2c.write,  self.port + self.addr,  storm.i2c.START, addr)
    if (rv ~= storm.i2c.OK) then
        print ("ERROR ON I2C: ",rv)
    end
    local dat = storm.array.create(12, storm.array.UINT8)
    rv = cord.await(storm.i2c.read,  self.port + self.addr,  storm.i2c.RSTART + storm.i2c.STOP, dat)
    if (rv ~= storm.i2c.OK) then
        print ("ERROR ON I2C: ",rv)
    end
    local ax = dat:get_as(storm.array.INT16_BE, 0)
    local ay = dat:get_as(storm.array.INT16_BE, 2)
    local az = dat:get_as(storm.array.INT16_BE, 4)
    local mx = dat:get_as(storm.array.INT16_BE, 6)
    local my = dat:get_as(storm.array.INT16_BE, 8)
    local mz = dat:get_as(storm.array.INT16_BE, 10)
    return ax, ay, az, mx, my, mz
end

function ACC:calibrate()
  local ax, ay, az, mx, my, mz = self:get()
  ACCEL_GVALUE = az
end

function ACC:get_mg()
  local ax, ay, az, mx, my, mz = self:get()
  return ax*1000 / ACCEL_GVALUE, ay*1000 / ACCEL_GVALUE, az*1000 / ACCEL_GVALUE 
end

return ACC