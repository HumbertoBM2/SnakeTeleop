-- File: snake_ros2_impulse.lua
sim     = require('sim')
simROS2 = require('simROS2')

-- Objetivo de velocidad (±1) y disparo de giro (impulso)
local targetSpeed = 0.0
local turnImpulse = 0.0

-- Parámetros de decaimiento del impulso de giro
local turnDecay = 0.90  -- cada paso multiplica el impulso por este factor

-- Variables de tu dinámica de serpiente
local s, model, modules
local mass, str, prox, proxCounter, proxTiming, maxHAngle
local moduleCount, interModuleDelay, verticalTable, horizontalTable, tableLength

-- Callback ROS2: solo dispara el impulso de giro y ajusta la velocidad
function callback_cmdVel(msg)
    -- velocidad hacia delante/atrás
    targetSpeed = msg.linear.x
    -- si hay giro, disparamos un impulso
    if msg.angular.z ~= 0 then
        turnImpulse = msg.angular.z
    end
end

function sysCall_init()
    -- ==== Inicialización modelo (idéntica a la tuya) ====
    model = sim.getObject('..')
    modules = {}
    for i=1,9 do
        local m = {}
        if i~=9 then
            m.vJoint = sim.getObject('../vJoint',{index=i-1})
            m.hJoint = sim.getObject('../hJoint',{index=i-1})
        end
        if i==1 then
            m.body = model
        else
            m.body = sim.getObject('../_bodyRespondable',{index=i-2})
        end
        m.bodyS = sim.getObject('../body',{index=i-1})
        modules[i] = m
    end

    prox = sim.getObject('../proxSensor')
    local obs = sim.createCollection(0)
    sim.addItemToCollection(obs,sim.handle_all,-1,0)
    sim.addItemToCollection(obs,sim.handle_tree,model,1)
    sim.setObjectInt32Param(prox,sim.proxintparam_entity_to_detect,obs)

    moduleCount      = 8
    interModuleDelay = 5
    verticalTable    = {}
    horizontalTable  = {}
    tableLength      = moduleCount*interModuleDelay
    for i=1,tableLength do
        table.insert(verticalTable,0)
        table.insert(horizontalTable,0)
    end

    mass, str           = 1.1, -20
    s                   = 0.0
    proxCounter, proxTiming = 0, 8
    maxHAngle           = 45

    -- ==== ROS2 Subscription ====
    sub = simROS2.createSubscription('/cmd_vel','geometry_msgs/msg/Twist','callback_cmdVel')
end

function sysCall_actuation()
    local dt   = sim.getSimulationTimeStep()
    local simT = sim.getSimulationTime()

    -- === 1) Actualiza fase de ondulación según targetSpeed ===
    -- backward serpenteo si targetSpeed < 0
    s = s + dt * targetSpeed * (2*math.cos(simT*0.5) + 0.3)
    local vPos = maxHAngle*(math.pi/180) * math.sin(s*2.5)

    -- === 2) Calcula hPos según el impulso de giro ===
    -- impulso en rango ±1 mapeado a ángulo máximo
    local hPos = maxHAngle*(math.pi/180) * turnImpulse

    -- decaer impulso cada paso
    turnImpulse = turnImpulse * turnDecay

    -- === 3) Lógica de proximidad (idéntica) ===
    if proxCounter==0 and sim.readProximitySensor(prox)==1 then
        proxCounter = proxTiming*4
    end
    if proxCounter>0 then proxCounter = proxCounter-1 end

    -- === 4) Desfase en tablas ===
    table.remove(verticalTable,tableLength)
    table.remove(horizontalTable,tableLength)
    table.insert(verticalTable,1,vPos)
    table.insert(horizontalTable,1,hPos)

    -- === 5) Aplicar posiciones a las juntas ===
    for i=1,(#modules-1) do
        sim.setJointTargetPosition(modules[i].vJoint,     verticalTable[(i-1)*interModuleDelay+1])
        sim.setJointTargetPosition(modules[i].hJoint, horizontalTable[(i-1)*interModuleDelay+1])
    end
end

function sysCall_cleanup()
    simROS2.shutdownSubscription(sub)
end
