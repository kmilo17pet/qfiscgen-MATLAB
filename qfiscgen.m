%QFISCGEN Generate C using the qFIS engine from a fis object.
%   STIMER( FIS ) Generate C-code from the supplied FIS object. 
%
%   qfiscgen( readfis('tipper.fis') )
%
%   See also READFIS, FUZZYS.
%
%   Author: J. Camilo Gomez C.
function varargout=qfiscgen(varargin)
    if nargin ~= 1
        error('A FIS Object must be supplied');
    end
    disp("Parsing FIS object...");
    fis=varargin{1};
    tabchar = string(blanks(4));
    objname = strtrim(fix2varname(fis.name));
    code = "/* Fuzzy inference system generated by qfiscgen.m for the qFIS engine*/" + newline;
    code = code + "/* Generated : " + string(datestr(now)) + " */" + newline;
    code = code + "/* Note: Obtain the qFIS engine from https://github.com/kmilo17pet/qlibs */" + newline + newline;
    code = code + '#include "' + objname + '_fis.h"' + newline + '#include "qFIS.h"' + newline + newline;
    fistype = 'Sugeno';  
    if (strcmp(fis.type,'mamdani'))
        fistype = 'Mamdani';
    end
    nins = length(fis.inputs);
    nouts = length(fis.outputs);
    code = code + "/* FIS Object */"+ newline;
    code = code + "static qFIS_t " + objname + ";" + newline;
    code = code + "/* I/O Fuzzy Objects */" + newline;
    fuzzin_arrname = objname + "_inputs";
    fuzzout_arrname = objname + "_outputs";
    code = code + "static qFIS_IO_t " + fuzzin_arrname + "[" + num2str(nins) + "], " + fuzzout_arrname + "[" + num2str(nouts) + "];" + newline;
    nin_mfs = length([fis.input(:).mf]);
    nout_mfs = length([fis.output(:).mf]);
    code = code + "/* I/O Membership Objects */" + newline;
    code = code + "static qFIS_MF_t MFin[" + num2str(nin_mfs)+  "], MFout[" + num2str(nout_mfs) + "];" + newline;
    code = code + "/* I/O Names */" + newline + "enum { ";

    innames=cell(1,length(fis.inputs));
    for k=1:length(fis.inputs)
        fis.inputs(k).name=fix2varname(fis.inputs(k).name);
        innames{k}=fis.inputs(k).name;
    end
    
    outnames=cell(1,length(fis.outputs));
    for k=1:length(fis.outputs)
        fis.outputs(k).name=fix2varname(fis.outputs(k).name);
        outnames{k}=fis.outputs(k).name;
    end

    mfinnames={};
    for k=1:nins
        for p=1:length(fis.inputs(k).membershipfunctions)
            fis.inputs(k).membershipfunctions(p).name  = fix2varname( fis.inputs(k).name + "_" + fis.inputs(k).membershipfunctions(p).name );
            mfinnames=[mfinnames fis.inputs(k).membershipfunctions(p).name];
            mfins{k}{p}= fis.inputs(k).membershipfunctions(p).name;
        end
    end
    mfoutnames={};
    for k=1:nouts
        for p=1:length(fis.outputs(k).membershipfunctions)
            fis.outputs(k).membershipfunctions(p).name  = fix2varname( fis.outputs(k).name + "_" + fis.outputs(k).membershipfunctions(p).name );
            mfoutnames=[mfoutnames fis.outputs(k).membershipfunctions(p).name];
            mfouts{k}{p}= fis.outputs(k).membershipfunctions(p).name;
        end
    end

    dem=", ";
    for k=1:length(fis.inputs)
        if k==length(fis.inputs)
           dem='';
        end
        code = code + innames{k} + dem;
    end
      
    code = code + "};" + newline + "enum { ";
    dem=", ";
    for k=1:length(fis.outputs)
        if k==length(fis.outputs)
           dem="";
        end
        code = code + outnames{k} +dem;
    end

    code = code + "};" + newline;
    code = code + "/* I/O Membership functions tags */" + newline + "enum { ";
    dem = ", ";
    for k=1:length(mfinnames)
        if k==length(mfinnames)
           dem="";
        end
        code = code + mfinnames{k}+ dem;
    end
    code = code  + "};" + newline + "enum { ";
    dem = ", ";
    for k=1:length(mfoutnames)
        if k==length(mfoutnames)
           dem="";
        end
        code = code + mfoutnames{k} + dem;
    end
    code = code + "};" + newline + newline;
    code = code + "static const qFIS_Rules_t rules[] = { " + newline + tabchar  + "QFIS_RULES_BEGIN" + newline;
   
    rw = 0;
    for k=1:length(fis.rules)
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
        code = code + r; 
        rw =  rw + fis.rules(k).Weight;
    end

    code = code +  tabchar + "QFIS_RULES_END" + newline + "};" + newline; 
    code = code + newline + "/*Parameters of the membership functions*/" + newline;
    for k=1:nins
        for l=1:length(fis.input(k).mf)
            strp = sprintf('%ff, ',fis.inputs(k).membershipfunctions(l).parameters);
            strp(end:-1:end-1)='';
            code = code + "static const float " + mfins{k}{l} + "_p[] = { " +  strp + " };" + newline;
        end
    end
    for k=1:nouts
        for l=1:length(fis.output(k).mf)
            strp = sprintf('%ff, ',fis.Outputs(k).membershipfunctions(l).parameters);
            strp(end:-1:end-1)='';
            code = code + "static const float " + mfouts{k}{l} + "_p[] = { " + strp + " };" + newline;
        end
    end

    if rw ~= length(fis.rules)
        srw = sprintf('%f, ', [fis.Rules(:).Weight]);
        srw(end:-1:end-1)='';
        code = code + "static const float ruleWeights[] = { " + srw + " };" + newline;
    end

    code = code + newline + "void " + objname + "_init( void ){" + newline;
    code = code + tabchar + "/* Add inputs */" + newline;
    for k=1:nins
        code = code + tabchar + "qFIS_SetIO( " + fuzzin_arrname + ", " + innames{k} + ", " +  sprintf("%ff",fis.input(k).range(1)) + ", " + sprintf("%ff",fis.input(k).range(2)) + " );" + newline;
    end 
       
    for k=1:nouts
        code = code + tabchar + "qFIS_SetIO( " +  fuzzout_arrname + ", " + outnames{k} + ", " + sprintf("%ff",fis.output(k).range(1)) + ", " + sprintf("%ff",fis.output(k).range(2)) + " );" + newline;
    end 
    code = code + tabchar + "/* Add membership functions to the inputs */" + newline; 
    
    for k=1:nins
        for l=1:length(fis.input(k).mf)
            strp = sprintf('%ff, ',fis.inputs(k).membershipfunctions(l).parameters);
            strp(end:-1:end-1)='';
            code = code + tabchar + "qFIS_SetMF( MFin, " + innames{k} + ", " + mfins{k}{l} + ", " + fis.input(k).mf(l).type + ", NULL, " + mfins{k}{l} + "_p" + ", 1.0f );" + newline;    
        end
    end
    code = code + tabchar + "/* Add membership functions to the outputs */" + newline; 
   
    for k=1:nouts
        for l=1:length(fis.output(k).mf)
            strp = sprintf('%ff, ',fis.Outputs(k).membershipfunctions(l).parameters);
            strp(end:-1:end-1)='';
            mftype = fis.outputs(k).mf(l).type;
            if mftype == "linear" || mftype == "constant"
                mftype = mftype + 'mf';
            end
            code = code + tabchar + "qFIS_SetMF( MFout, " + outnames{k} + ", " + mfouts{k}{l} + ", " + mftype + ", NULL, " + mfouts{k}{l} + "_p" + ", 1.0f );" + newline;  
        end
    end

    code = code + newline + tabchar + "/* Configure the Inference System */" + newline +... 
           tabchar + "qFIS_Setup( &" + objname + ", " + fistype +"," + newline + ...
           tabchar + blanks(12) + fuzzin_arrname + ", sizeof(" + fuzzin_arrname + ")," + newline + ...
           tabchar + blanks(12) + fuzzout_arrname + ", sizeof(" + fuzzout_arrname + ")," + newline + ...
           tabchar + blanks(12) + "MFin, sizeof(MFin), MFout, sizeof(MFout) );" + newline; 

    
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

    code = code + "}" + newline + newline;
    code = code + "void " + objname + "_run( float *inputs, float *outputs ) {" + newline; 

    code = code + tabchar + "/* Set the crips inputs */" + newline;
    for k=1:nins
        code = code + tabchar + fuzzin_arrname + "[ " + innames{k} + " ].value = inputs[ " + innames{k} + " ]" + newline;
    end
    code = code + newline + tabchar + "qFIS_Fuzzify( &" + objname + " );" + newline;
    code = code + tabchar + "if ( qFIS_Inference( &" + objname + ", rules ) > 0 ) {" + newline;
    code = code + tabchar + tabchar + "qFIS_DeFuzzify( &" + objname + " );" + newline;
    code = code + tabchar + "else {" + newline + tabchar + tabchar + "/* Error! */" + newline + tabchar + "}" + newline;
    code = code + newline + tabchar + "/* Get the crips outputs */" + newline;
    for k=1:nouts
        code = code + tabchar + "outputs[ " + outnames{k} + " ] = " + fuzzout_arrname + "[ " + outnames{k} + " ].value;" + newline;
    end
    code = code + "}";
    disp("Creating " + objname + "_fis.c ...");
    fid = fopen(objname + "_fis.c",'wt');
    fprintf(fid, code);
    fclose(fid);

    code = "/* Fuzzy inference system generated by qfiscgen.m for the qFIS engine*/" + newline + ...
           "/* Generated : " + string(datestr(now)) + " */" + newline +...
           "/* Note: Obtain the qFIS engine from https://github.com/kmilo17pet/qlibs */" + newline + newline +....
           "#ifndef QFIS_H" + newline +...
           "#define QFIS_H" + newline +... 
           "#ifdef __cplusplus" + newline +...
           tabchar + 'extern "C" {' + newline +...
           "#endif" + newline + newline +...
           tabchar + "void " + objname + "_init( void );" + newline +...
           tabchar + "void " + objname + "_run( float *inputs, float *outputs );" + newline + newline +...
           "#ifdef __cplusplus" + newline +...
           tabchar + '}' + newline +...
           "#endif" + newline;
    disp("Creating " + objname + "_fis.h ...");
    fid = fopen(objname + "_fis.h",'wt');
    fprintf(fid, code);
    fclose(fid);
    varargout = {};
    disp("Done!")
end

function b = fix2varname(a)
    a=a(find((a>=char(65) & a<=char(90)) | (a>=char(97) & a<=char(122)), 1,'first'):end);    
    b = a( (a>=char(48) & a<=char(57)) | (a>=char(65) & a<=char(90)) | (a>=char(97) & a<=char(122)) | a==char(32));
    b(b==char(32))='_';
    b=b(find(b>char(65),1,'first'):end);
    b=strrep(b,' ','_');
    b=strrep(b,'__','_');
end
