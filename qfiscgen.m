%QFISCGEN qFIS C-code generator.
%   QFISCGEN( FIS ) Generate C-code from the supplied FIS object.
%
%   qfiscgen( readfis('tipper.fis') )
%
%   See also READFIS, FUZZY, FISRULE.

%	Version 2.104
%   Copyright 2022 J. Camilo Gomez C.
function varargout=qfiscgen(varargin)
    narginchk( 1, 1);
    fis=varargin{1};
    try 
        mamfis("Name","test");
    catch
        error('Fuzzy Logic Toolbox not found or MATLAB version too old. >R1018b required')
    end
    disp("Parsing FIS object " + fis.name + "...");
    tabchar = string(blanks(4));
    objname = strtrim(fix2varname(fis.name));
    fistype = 'Sugeno';  
    if (strcmp(fis.type,'mamdani'))
        fistype = 'Mamdani';
    end
    nins = length(fis.inputs);
    nouts = length(fis.outputs);
    fuzzin_arrname = objname + "_inputs";
    fuzzout_arrname = objname + "_outputs";
    nin_mfs = length( [ fis.inputs(:).membershipfunctions ] );
    nout_mfs = length( [ fis.outputs(:).membershipfunctions ] );

    mfinnames = [];
    mfoutnames=[];
    codeparams = "";
    codemfsetup = tabchar + "/* Set membership functions for the inputs */" + newline;
    codeiosetup = tabchar + "/* Set inputs */" + newline;
    coderun1 = "";
    coderun2 = "";
    coderulew = "";
    
    innames = strings(1,length(fis.inputs));
    for k=1:nins
        fis.inputs(k).name=fix2varname(fis.inputs(k).name);
        innames(k) = fis.inputs(k).name;
        codeiosetup = codeiosetup + tabchar + "qFIS_InputSetup( " + fuzzin_arrname + ", " + innames{k} + ", " +  sprintf("%.4ff",fis.input(k).range(1)) + ", " + sprintf("%.4ff",fis.input(k).range(2)) + " );" + newline;
        for p=1:length(fis.inputs(k).membershipfunctions)
            if 0 == checkmf( fis.input(k).mf(p).type )
                error('Custom membership functions are not supported');
            end
            fis.inputs(k).membershipfunctions(p).name  = fix2varname( fis.inputs(k).name + "_" + fis.inputs(k).membershipfunctions(p).name );
            mfinnames= [mfinnames  fis.inputs(k).membershipfunctions(p).name ]; %#ok
            mfin= fis.inputs(k).membershipfunctions(p).name;
            strp = sprintf('%.4ff, ',fis.inputs(k).membershipfunctions(p).parameters);
            strp(end:-1:end-1)='';
            codeparams = codeparams + "static const float " + mfin + "_p[] = { " +  strp + " };" + newline;
            codemfsetup = codemfsetup + tabchar + "qFIS_SetMF( MFin, " + innames{k} + ", " + mfin + ", " + fis.input(k).mf(p).type + ", NULL, " + mfin + "_p" + ", 1.0f );" + newline;   
        end
        coderun1 = coderun1 + tabchar + "qFIS_SetInput( " + fuzzin_arrname + ", " + innames{k} + ", inputs[ " + innames{k} + " ] );" + newline;
    end
    codemfsetup = codemfsetup + tabchar + "/* Set membership functions for the outputs */" + newline; 
    outnames = strings(1,length(fis.outputs));
    codeiosetup = codeiosetup + tabchar + "/* Set outputs */" + newline;
    for k=1:nouts
        fis.outputs(k).name=fix2varname(fis.outputs(k).name);
        outnames(k) = fis.outputs(k).name;
        codeiosetup = codeiosetup + tabchar + "qFIS_OutputSetup( " + fuzzout_arrname + ", " + outnames{k} + ", " + sprintf("%.4ff",fis.output(k).range(1)) + ", " + sprintf("%.4ff",fis.output(k).range(2)) + " );" + newline;
        for p=1:length(fis.outputs(k).membershipfunctions)
            if 0 == checkmf( fis.outputs(k).mf(p).type )
                error('Custom membership functions are not supported');
            end
            fis.outputs(k).membershipfunctions(p).name  = fix2varname( fis.outputs(k).name + "_" + fis.outputs(k).membershipfunctions(p).name );
            mfoutnames=[mfoutnames fis.outputs(k).membershipfunctions(p).name]; %#ok
            mfout = fis.outputs(k).membershipfunctions(p).name;
            strp = sprintf('%.4ff, ',fis.Outputs(k).membershipfunctions(p).parameters);
            strp(end:-1:end-1)='';
            codeparams = codeparams + "static const float " + mfout + "_p[] = { " + strp + " };" + newline; 
            mftype = fis.outputs(k).mf(p).type;
            if mftype == "linear" || mftype == "constant"
                mftype = mftype + 'mf';
            end
            codemfsetup = codemfsetup + tabchar + "qFIS_SetMF( MFout, " + outnames{k} + ", " + mfout + ", " + mftype + ", NULL, " + mfout + "_p" + ", 1.0f );" + newline;
        end
        coderun2 = coderun2 + tabchar + "outputs[ " + outnames{k} + " ] = " + "qFIS_GetOutput( " +  fuzzout_arrname + ", " + outnames{k} + " );" + newline;
    end
    
    
    [ rules_code, rw ] = rules_gen( fis );
    if rw ~= length(fis.rules)
        srw = sprintf('%0.2ff, ', [fis.Rules(:).Weight]);
        srw(end:-1:end-1)='';
        coderulew = "/* Rule weighs */" + newline + ...
                    "static const float ruleWeights[] = { " + srw + " };" + newline;
    end

    code = '#include "' + objname + '_fis.h"' + newline + ... 
           '#include "qfis.h"' + newline + newline + ...
           "/* FIS Object */"+ newline + ...
           "static qFIS_t " + objname + ";" + newline + ...
           "/* I/O Fuzzy Objects */" + newline + ...
           "static qFIS_Input_t " + fuzzin_arrname + "[ " + num2str(nins) + " ];" + newline + ...
           "static qFIS_Output_t "+  fuzzout_arrname + "[ " + num2str(nouts) + " ];" + newline + ...
           "/* I/O Membership Objects */" + newline + ...
           "static qFIS_MF_t MFin[ " + num2str(nin_mfs)+  " ], MFout[ " + num2str(nout_mfs) + " ];" + newline + ...
           "/* I/O Names */" + newline + ...
           "enum { " +  strjoin( innames, ", " ) + " };" + newline + ...
           "enum { " +  strjoin( outnames, ", " ) + " };" + newline + ...
           "/* I/O Membership functions tags */" + newline + ...
           "enum { " +  strjoin( mfinnames, ", " ) + " };" + newline + ... 
           "enum { " +  strjoin( mfoutnames, ", " ) + " };" + newline + ... 
           "/* Rules of the inference system */" + newline + ...
           "static const qFIS_Rules_t rules[] = { " + newline + ...
           tabchar  + "QFIS_RULES_BEGIN" + newline + ...
           rules_code + ... 
           tabchar + "QFIS_RULES_END" + newline + "};" + newline + ...
           "/* Rule strengths */" + newline + ...
           "float rStrength[ " +  string(length(fis.rules)) + " ] = { 0.0f };" + newline + ...
           coderulew +  newline + ...
           "/* Parameters of the membership functions */" + newline + ...
           codeparams + newline + ...
           "void " + objname + "_init( void ){" + newline + ...
           codeiosetup + ...
           codemfsetup + ...
           newline + tabchar + "/* Configure the Inference System */" + newline +... 
           tabchar + "qFIS_Setup( &" + objname + ", " + fistype +"," + newline + ...
           tabchar + blanks(12) + fuzzin_arrname + ", sizeof(" + fuzzin_arrname + ")," + newline + ...
           tabchar + blanks(12) + fuzzout_arrname + ", sizeof(" + fuzzout_arrname + ")," + newline + ...
           tabchar + blanks(12) + "MFin, sizeof(MFin), MFout, sizeof(MFout)," + newline + ...
           tabchar + blanks(12) + "rules, rStrength, " + string(length(fis.rules)) + "u );" + newline;
           

    if fis.type == "mamdani" && fis.DefuzzificationMethod ~= "centroid" 
        code = code + tabchar + "qFIS_SetDeFuzzMethod( &"+ objname + ", " + fis.DefuzzificationMethod + " );" + newline;
    end
    
    if fis.type == "sugeno" && fis.DefuzzificationMethod ~= "wtaver" 
        code = code + tabchar + "qFIS_SetDeFuzzMethod( &"+ objname + ", " + fis.DefuzzificationMethod + " );" + newline;
    end

    if fis.AndMethod ~= "min" 
        code = code + tabchar + "qFIS_SetParameter( &"+ objname + ", qFIS_AND, qFIS_" + upper(fis.AndMethod) + " );" + newline;
    end

    if fis.OrMethod ~= "max" 
        code = code + tabchar + "qFIS_SetParameter( &"+ objname + ", qFIS_OR, qFIS_" + upper(fis.OrMethod) + " );" + newline;
    end

    if fis.ImplicationMethod ~= "min" 
        code = code + tabchar + "qFIS_SetParameter( &"+ objname + ", qFIS_Implication, qFIS_" + upper(fis.ImplicationMethod) + " );" + newline;
    end

    if fis.AggregationMethod ~= "max" 
        code = code + tabchar + "qFIS_SetParameter( &"+ objname + ", qFIS_Aggregation, qFIS_" + upper(fis.AggregationMethod) + " );" + newline;
    end

    if rw ~= length(fis.rules)
        code = code + tabchar + "qFIS_SetRuleWeights( &"+ objname + ", ruleWeights );" + newline;
    end

    code = code + "}" + newline + newline + ...
           "void " + objname + "_run( float *inputs, float *outputs ) {" + newline + ... 
           tabchar + "/* Set the crips inputs */" + newline + ...
           coderun1 + newline + ...
           tabchar + "qFIS_Fuzzify( &" + objname + " );" + newline + ...
           tabchar + "if ( qFIS_Inference( &" + objname + " ) > 0 ) {" + newline + ...
           tabchar + tabchar + "qFIS_DeFuzzify( &" + objname + " );" + newline + ...
           tabchar + "}" + newline + ...
           tabchar + "else {" + newline + tabchar + tabchar + "/* Error! */" + newline + ...
           tabchar + "}" + newline + newline + ...
           tabchar + "/* Get the crips outputs */" + newline + ...
           coderun2 + ...
           "}";

    header = "#ifndef " + upper(objname) + "_FIS_H" + newline +...
             "#define " + upper(objname) + "_FIS_H" + newline + newline + ... 
             "#ifdef __cplusplus" + newline +...
             tabchar + 'extern "C" {' + newline +...
             "#endif" + newline + newline +...
             tabchar + "void " + objname + "_init( void );" + newline +...
             tabchar + "void " + objname + "_run( float *inputs, float *outputs );" + newline + newline +...
             "#ifdef __cplusplus" + newline +...
             tabchar + '}' + newline +...
             "#endif" + newline + newline + ...
             "#endif /* " + upper(objname) + "_FIS_H */" + newline;

    consolidate( objname, code, header);
    varargout = {};
    disp("Done!")
end
%--------------------------------------------------------------------------
function [rcode, rw] = rules_gen( fis )
    rw = 0;
    tabchar = string(blanks(4));
    rcode = "";
    for k=1:length(fis.rules)
        if  contains( extractAfter( fis.rules(k).description, "=>" ), "~" ) 
            error("Negated consequents are not supported");
        end
        r = tabchar + tabchar + "IF " + fis.rules(k).Description;
        r = strrep( r, "=>", "THEN");
        r = strrep( r, "==", " IS ");
        r = strrep( r, "~=", " IS_NOT ");
        r = strrep( r, "=", " IS ");
        r = strrep( r, ",", " AND");
        r = strrep( r, "&", " AND");
        r = strrep( r, "|", " OR");
        r = strrep( r, "  "," ");
        r = eraseBetween(r,"(",")",'Boundaries','inclusive');
        r = r + "END" + newline;
        rcode = rcode + r; 
        rw =  rw + fis.rules(k).Weight;
    end
end
%--------------------------------------------------------------------------
function consolidate( name, code_c, code_h )
    head = "/* Fuzzy inference system generated by qfiscgen.m for the qFIS engine*/" + newline + ...
           "/* Generated : " + string(datetime) + " */" + newline +...
           "/* MATLAB Version: " + string(version) + " */" + newline + ...
           "/* Note: Based on the qFIS engine from https://github.com/kmilo17pet/qlibs */" + newline + newline;
    disp("Creating " + name + "_fis.c ...");
    filename_c = fullfile( pwd,name+ "_fis.c" );
    fid = fopen( filename_c, 'wt');
    fprintf( fid, head+code_c );
    fclose( fid );
    disp("Creating " + name + "_fis.h ...");
    filename_h = fullfile( pwd,name+ "_fis.h" );
    fid = fopen( filename_h,'wt');
    fprintf(fid, head + code_h);
    fclose(fid);
    disp('Obtaining latest qFIS engine from https://github.com/kmilo17pet/qlibs/ ...');
    try
        websave( fullfile(pwd,'qfis.c'), 'https://github.com/kmilo17pet/qlibs/raw/main/qfis.c');
        disp('qfis.c obtained')
        websave( fullfile(pwd,'qfis.h'), 'https://github.com/kmilo17pet/qlibs/raw/main/include/qfis.h');
        disp('qfis.h obtained')
    catch
        disp('qFIS engine cannot be obtained, please download it manually from https://github.com/kmilo17pet/qlibs/')
    end
end
%--------------------------------------------------------------------------
function b = fix2varname(a)
    a=a(find((a>=char(65) & a<=char(90)) | (a>=char(97) & a<=char(122)), 1,'first'):end);    
    b = a( (a>=char(48) & a<=char(57)) | (a>=char(65) & a<=char(90)) | (a>=char(97) & a<=char(122)) | a==char(32));
    b(b==char(32))='_';
    b=b(find(b>char(65),1,'first'):end);
    b = string(b);
    b=replace(b,' ','_');
    b=replace(b,"-","_");
    b=replace(b,"(","_");
    b=replace(b,")","_");
    b=replace(b,'__','_');
    if isempty(b)
        b = "fis";
    end
end
%--------------------------------------------------------------------------
function y = checkmf( mfname )
    y = sum( mfname == ["trimf" "trapmf" "gbellmf" "gaussmf" "gauss2mf" "sigmf" "dsigmf" "psigmf" "pimf" "smf" "zmf" "linsmf" "linzmf" "linear" "constant"] );
end
%--------------------------------------------------------------------------