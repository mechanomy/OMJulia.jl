module TestOMJulia
  using OMJulia
  using Test

  function check(string, expected_value, expected_type)
    value = OMJulia.Parser.parseOM(string)
    expected_value == value && expected_type == typeof(value)
  end

  @testset "OMJulia" begin
    @testset "Parser" begin
      @test check("123.0", 123.0, Float64)
      @test check("123", 123, Int)
      @test check("1.", 1.0, Float64)
      @test check(".2", 0.2, Float64)
      @test check("1e3", 1e3, Float64)
      @test check("1e+2", 1e+2, Float64)
      @test check("tRuE", true, Bool)
      @test check("false", false, Bool)
      @test check("\"ab\\nc\"", "ab\nc", String)
      @test check("{\"abc\"}", ["abc"], Array{String,1})
      @test check("{1}", [1], Array{Int,1})
      @test check("{1,2,3}", [1,2,3], Array{Int,1})
      @test check("(1,2,3)", (1,2,3), Tuple{Int,Int,Int})
      @test check("NONE()", nothing, Nothing)
      @test check("SOME(1)", 1, Int)
      @test check("abc_2", :abc_2, Symbol)
      @test check("record ABC end ABC;", Dict(), Dict{String,Any})
      @test check("record ABC a = 1, 'b' = 2,\n  c = 3\nend ABC;", Dict("a" => 1, "'b'" => 2, "c" => 3), Dict{String,Int})
      @test check("", nothing, Nothing)
    end

    @testset "OpenModelica" begin
      omc = OMJulia.OMCSession()
      @test 3==OMJulia.sendExpression(omc, "1+2")
      OMJulia.sendExpression(omc, "quit()", parsed=false)
    end
  end

  @testset "sendExpression(simulate()) - builtin" begin
    omc = OMJulia.OMCSession()
    try
      ret = OMJulia.sendExpression(omc, "loadModelica()")
      ret = OMJulia.sendExpression(omc, "loadModel(Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum)")
      ret = OMJulia.sendExpression(omc, "simulate(Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum)")
      @test !isempty(ret["resultFile"]) && isfile(ret["resultFile"])
    catch e
      println("\ncaught error[$e]\n")
      @test false
    finally
      OMJulia.sendExpression(omc, "quit()", parsed=false)
    end
  end

  # Write a copy of the Modelica.MultiBody.Examples.Elementary.Pendulum used above to a temp file:
  pendulumText = """model Pendulum "Simple pendulum with one revolute joint and one body"
      extends Modelica.Icons.Example;
      inner Modelica.Mechanics.MultiBody.World world(gravityType=Modelica.Mechanics.MultiBody.Types.GravityTypes.  UniformGravity);
      Modelica.Mechanics.MultiBody.Joints.Revolute rev(n={0,0,1},useAxisFlange=true, phi(fixed=true), w(fixed=true));
      Modelica.Mechanics.Rotational.Components.Damper damper( d=0.1);
      Modelica.Mechanics.MultiBody.Parts.Body body(m=1.0, r_CM={0.5,0,0});
    equation
      connect(world.frame_b, rev.frame_a);
      connect(damper.flange_b, rev.axis);
      connect(rev.support, damper.flange_a);
      connect(body.frame_a, rev.frame_b);
      annotation ( experiment(StopTime=5));
    end Pendulum;
    """
  pendulumName = "Pendulum"
  tempDir = mktempdir(prefix="test_OMJulia_")
  pendulumPath = joinpath(tempDir, pendulumName*".mo")
  pendulumPath = replace(pendulumPath, "\\"=>"/") # omc only accepts forward slash paths
  write(pendulumPath, pendulumText)
 
  @testset "sendExpression(simulate()) - file based" begin
    @test isfile(pendulumPath)
    omc = OMJulia.OMCSession()
    try
      ret = OMJulia.sendExpression(omc, "loadModelica()")
      ret = OMJulia.sendExpression(omc, "loadFile(\"$pendulumPath\")")
      ret = OMJulia.sendExpression(omc, "loadModel(\"$pendulumName\")")
      ret = OMJulia.sendExpression(omc, "buildModel($pendulumName)")
      ret = OMJulia.sendExpression(omc, "simulate($pendulumName)")
      @test haskey(ret, "resultFile") && !isempty(ret["resultFile"]) && isfile(ret["resultFile"])
    catch e
      println("\ncaught error:")
      dump(e)
      @test false
    finally
      OMJulia.sendExpression(omc, "quit()", parsed=false)
    end
    @test true
  end

  @testset "ModelicaSystem-simulate()" begin 
    @test isfile(pendulumPath)
    omc = OMJulia.OMCSession()
    try
      OMJulia.ModelicaSystem(omc, pendulumPath, pendulumName)
      ret = OMJulia.simulate(omc)
      @test haskey(ret, "resultFile") && !isempty(ret["resultFile"]) && isfile(ret["resultFile"])
    catch e
      println("\ncaught error:")
      dump(e)
      @test false
    finally
      OMJulia.sendExpression(omc, "quit()", parsed=false)
    end
  end

end