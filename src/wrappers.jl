#=
This file is part of OpenModelica.
Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
c/o Linköpings universitet, Department of Computer and Information Science,
SE-58183 Linköping, Sweden.

All rights reserved.

THIS PROGRAM IS PROVIDED UNDER THE TERMS OF THE BSD NEW LICENSE OR THE
GPL VERSION 3 LICENSE OR THE OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
ACCORDING TO RECIPIENTS CHOICE.

The OpenModelica software and the OSMC (Open Source Modelica Consortium)
Public License (OSMC-PL) are obtained from OSMC, either from the above
address, from the URLs: http://www.openmodelica.org or
http://www.ida.liu.se/projects/OpenModelica, and in the OpenModelica
distribution. GNU version 3 is obtained from:
http://www.gnu.org/copyleft/gpl.html. The New BSD License is obtained from:
http://www.opensource.org/licenses/BSD-3-Clause.

This program is distributed WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, EXCEPT AS
EXPRESSLY SET FORTH IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE
CONDITIONS OF OSMC-PL.
=#

"""
Sends the `cmd` followed by getErrorString(), returning true if the command succeeded or if false throws an ArgumentError with the received error string.
Provide `expected` for commands that do not indicate success with a Boolean true, eg 'cd()' which returns the directory if successful.
"""
function execute(omc, cmd; expected=true)
    ret = OMJulia.sendExpression(omc, cmd)
    ges = OMJulia.sendExpression(omc, "getErrorString()")

    if ret === expected
        return true
    else
        throw(ArgumentError("Executing command [$cmd] returned [$ret] and and error string [$ges]") )
        return false
    end
end

"""
OMC requires all paths to be forward-slash(/) delineated, regardless of operating system.
"""
function makeOMCPath(filepath)
    return replace(abspath(filepath), "\\"=>"/") 
end

"""
Loads the Modelica file at `filepath`.
"""
function loadFile(omc, filePath)
    if isfile(filePath) #is this necessary, or will loadFile check and communicate these?
        if last(splitext(filePath)) == ".mo" || last(splitext(filePath)) == ".MO"
            return execute(omc, "loadFile(\"$(makeOMCPath(filePath))\")", expected=nothing) 
        else
            throw(ArgumentError("File extension is not '.mo', cannot loadFile()"))
        end
    else
        throw(ArgumentError("No file found at [$filePath], cannot loadFile()."))
        return false
    end
end

"""
Loads the `modelName` model within the OMC instance, say from a loaded file.
"""
function loadModel(omc, modelName) 
    return execute(omc, "loadModel(\"$modelName\")", expected=nothing) 
end

function loadModelica(omc) #how about version? or will MSL be loaded by automatically by loadFile() with uses?
    return execute(omc, "loadModel(Modelica)", expected=nothing)
end

function checkModel(omc, modelName)::Bool
    ret = OMJulia.sendExpression(omc, "checkModel($modelName)")
    ges = OMJulia.sendExpression(omc, "getErrorString()")

    #if the check succeeds, the numbers of variables and equations are returned in text
    # ret = sendExpression(omc, "checkModel($(modelName))") = "Check of FallingBodies completed successfully.\nClass FallingBodies has 1811 equation(s) and 1811 variable(s).\n1366 of these are trivial equation(s)."
    #otoh, the check can fail for
    # syntax: ret="", ges = sendExpression(omc, "getErrorString()") = "[.../FallingBodies.mo:12:3-12:119:writable] Error: Variable freeMotion8.frame_a not found in scope FallingBodies.\n"
    # eqn!=var: 

    if ret !== nothing
        suc = match(r".*successfully.*", ret)
        if suc !== nothing
            return true
        else
            println("$modelName failed checking due to ret[$ret] with error[$ges]")
            return false
            # @show m = match(r".*has (?<nEqn>[0-9]*) equation\(s\) and (?<nVar>[0-9]*) variable", ret)
            # println("Model failed checking, nVars[$(m.nVar)] != nEqn[$(m.nEqn)]")
        end
    else
        return false
    end
end

function setDirectory(omc, dir)
    # omc requires absolute paths, so convert everything to absolute
    # prePath = abspath(sendExpression(omc, "getModelicaPath()"))
    newPath = abspath(dir) # if relative this will be taken from julia's invocation path..?

    # omc doesn't handle escapes in the same way: 
    #                   sendExpression(omc, "getModelicaPath()") = "C:/Users/BenConrad/AppData/Roaming/.openmodelica/libraries/"
    # prePath = abspath(sendExpression(omc, "getModelicaPath()")) = "C:\\Users\\BenConrad\\AppData\\Roaming\\.openmodelica\\libraries\\"
    # newPath = abspath(dir) = "W:\\sync\\mechgits\\library\\julia\\ConvenientModelica\\test\\FallingBodies\\"
    # ArgumentError("invalid escape sequence \\s")
    # so I need sttrep \\ to /
    newPath = replace(newPath, "\\" => "/")

    # the api lists several different paths, building is done in the working directory, set by cd():

    ret = false
    if isdir(newPath) # do not use isdirpath()
        # ret = sendExpression(omc, "setModelicaPath(\"$newPath\")")
        ret = OMJulia.sendExpression(omc, "cd(\"$newPath\")")
    else #if given a file, use its directory
        ret = OMJulia.sendExpression(omc, "cd(\"$(dirname(newPath))\")")
    end
    ges = OMJulia.sendExpression(omc, "getErrorString()")
    # posPath = abspath(OMJulia.sendExpression(omc, "getModelicaPath()"))

    if Base.Filesystem.samefile(ret, newPath)
        # println("setDir true")
        return true
    else
        println("setDir false ret[$ret] ges[$ges]")
        return false
    end
end

function buildModel(omc, modelName)
    ret = OMJulia.sendExpression(omc, "buildModel($modelName)")
    ges = OMJulia.sendExpression(omc, "getErrorString()")

    if !isempty(ret[2]) # from https://github.com/OpenModelica/OMJulia.jl/blob/67f69adb6dfc711402e08ed5feb87983796d4475/src/OMJulia.jl#L311
        return true
    else
        println("buildModel($modelName) failed with ret[$ret] and error[$ges]")
        return false
    end
end

function simulate(omc, modelName, resultPath)
    ret = OMJulia.sendExpression(omc, "simulate($modelName)")
    ges = OMJulia.sendExpression(omc, "getErrorString()")

    if !isempty(ret["resultFile"]) && isfile(ret["resultFile"])
        # display(ret["messages"])
        cp(ret["resultFile"], resultPath, force=true)
        println("Simulation succeeded, result file located at $resultPath")
        return true
    else
        println("simulation failed, returning:")
        dump(ret)
        println("with error string [$ges]")
        return false
    end
end

function simulateModel(modelName, modelPath, resultPath)
    omc = OMJulia.OMCSession()
    proceed = true
    try
        proceed &= loadModelica(omc)
        proceed &= loadFile(omc, modelPath)
        proceed &= loadModel(omc, modelName)
        proceed &= checkModel(omc, modelName)
        tdir = mktempdir(prefix="WrapOMC_", cleanup=true)
        proceed &= setDirectory(omc, tdir)
        proceed &= buildModel(omc, modelName)
        proceed &= simulate(omc, modelName, resultPath)
    catch e
        println("simulateModel() caught: $e")
    finally
        OMJulia.sendExpression(omc, "quit()", parsed=false)
    end
    return proceed
end




