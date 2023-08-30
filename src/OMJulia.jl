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

module OMJulia
include("session.jl") # low-level session interfacing

export ModelicaSystem


"""
Main function which constructs the datas and parameters needed for simulation
linearization of a model, The function accepts five aguments. The fourth argument is library is optional and fifth argument setCommandLineOptions which is a keyword argument is also optional, An example usage is given below
ModelicaSystem(obj,"BouncingBall.mo","BouncingBall",["Modelica", "SystemDynamics"],commandLineOptions="-d=newInst")
"""
function ModelicaSystem(omc, filename, modelname, library=nothing; commandLineOptions=nothing, variableFilter=nothing)
    ## check for commandLineOptions
    if (commandLineOptions !== nothing)
        exp = join(["setCommandLineOptions(","","\"",commandLineOptions,"\"" ,")"])
        cmdexp = sendExpression(omc, exp)
        if (!cmdexp)
            return println(sendExpression(omc, "getErrorString()"))
        end
    end

    omc.filepath = filename
    omc.modelname = modelname
    omc.variableFilter = variableFilter
    filepath = replace(abspath(filename), r"[/\\]+" => "/")
    if (isfile(filepath))
        loadmsg = sendExpression(omc, "loadFile(\"" * filepath * "\")")
        if (!loadmsg)
            return println(sendExpression(omc, "getErrorString()"))
        end
    else
        return println(filename, "! NotFound")
    end
    omc.tempdir = replace(mktempdir(), r"[/\\]+" => "/")
    if (!isdir(omc.tempdir))
        return println(omc.tempdir, " cannot be created")
    end
    sendExpression(omc, "cd(\"" * omc.tempdir * "\")")
    # load Libraries provided by users
    if (library !== nothing)
        if (isa(library, String))
            loadLibraryHelper(omc, library)
        # allow users to provide library version eg.(Modelica, "3.2.3")
        elseif (isa(library, Tuple{String, String}))
            if (!isempty(library[2]))
                loadLibraryHelper(omc, library[1], library[2])
            else
                loadLibraryHelper(omc, library[1])
            end
        elseif (isa(library, Array))
            for i in library
                # allow users to provide library version eg.(Modelica, "3.2.3")
                if isa(i, Tuple{String, String})
                    if (!isempty(i[2]))
                        loadLibraryHelper(omc, i[1], i[2])
                    else
                        loadLibraryHelper(omc, i[1])
                    end
                elseif isa(i, String)
                    loadLibraryHelper(omc, i)
                else
                    println("| info | loadLibrary() failed, Unknown type detected: ", i , " is of type ",  typeof(i), ", The following types are supported\n1)Strings\n2)Tuple{String, String}\n3)Array{Strings}\n4)Array{Tuple{String, String}}" )
                end
            end
        else
            println("| info | loadLibrary() failed, Unknown type detected: ", i , " is of type ",  typeof(i), ", The following types are supported\n1)Strings\n2)Tuple{String, String}\n3)Array{Strings}\n4)Array{Tuple{String, String}}" )
        end
    end
    buildModel(omc)
end




end
