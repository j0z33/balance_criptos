#!/bin/bash
#Declaramos la variables que podemos usar para formatear el color del texto
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

#si hacemos control+c para salir de la aplicación se ejecuta la función ctrl_c
trap ctrl_c INT

function ctrl_c(){
        #salimos
        echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Exiting...\n${endColour}"
        #borramos los ficheros que genera la aplicación
        rm ut.table 2>/dev/null
        rm ut2.table 2>/dev/null
        rm valor_ini.count valor_act.count 2>/dev/null
        #devolvemos el cursor (que hemos ocultado con tput civic al final) y realizamos una salida "NO" exitosa
        tput cnorm; exit 1
}

#variables globales
criptos=$1

if [[ ! ${criptos} || ! -f $criptos  ]]; then
        echo -e "\n${yellowColour}[*]Debes indicar un fichero con los valores de las criptomonedas separados por ;(punto y coma). Aplicados en el siguiente orden:${endColour}"
        echo -e "${yellowColour}   NombreMoneda;siglasMoneda;CantidadComprada;PrecioCompra${endColour}"
        echo -e "${yellowColour}[-]Es importante poner las siglas correctas de cada moneda${endColour}"
        echo -e "\t\n${blueColour}  Ejemplo:${endColour}"
        echo -e "\t\t${blueColour}  bitcoin;BTC;0,00114316;42.893${endColour}\n"
        echo -e ""

        tput cnorm; exit 1
fi

######################################Estas funciones son para generar tablas##########################
function printTable(){

    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

function removeEmptyLines(){

    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString(){

    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString(){

    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){

    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

#####################################################################hasta aquí llegan las funciones de tablas#######################
tput civis

cabecera="Moneda;Siglas;Cantidad;PrecioCompra \$;Precio Actual \$;Valor Inicial \$;ValorActual \$;Perdida/Ganancia \$"
echo $cabecera >> ut.table

for i in $(cat $criptos); do
        precio_act=""
        precio_compra=$(echo $i | awk  '{print $4}' FS=";" | tr -d '.')
        nombre=$(echo $i | awk '{print $1}' FS=";" | tr -d '.')
        siglas=$(echo $i | awk '{print $2}' FS=";" | tr -d '.')
        while [ "$(echo $precio_act)" == ""  ]; do
                precio_act=$(curl -s "https://min-api.cryptocompare.com/data/price?fsym=$siglas&tsyms=USD,EUR" | awk '{print $1}' FS="," | awk '{print $2}' FS=":" | tr '.' ',')
        done
        cantidadComprada=$(echo $i | awk '{print $3}' FS=";" | tr -d '.')
        val_ini=$(bc <<< "scale=4; $(echo $cantidadComprada | tr ',' '.') * $(echo $precio_compra | tr ',' '.')" | tr '.' ',')
        echo $val_ini | tr -d ' ' >> valor_ini.count
        val_act=$(bc <<< "scale=4; $(echo $cantidadComprada | tr ',' '.') * $(echo $precio_act | tr ',' '.')")
        echo $val_act >> valor_act.count
        balance=$(bc <<< "scale=4; $(echo $val_act | tr ',' '.') - $(echo $val_ini | tr ',' '.')")
        tabla="$nombre;$siglas;$cantidadComprada;$precio_compra;$precio_act;$val_ini;$(echo $val_act | tr '.' ',');$(echo $balance | tr '.' ',')"
        echo $tabla >> ut.table
done

echo -ne "${yellowColour}"
printTable ';' "$(cat ut.table)"
echo -ne "${endColour}"
valorInicialTotal=0
valorActualTotal=0
cabecera2="Valor Inicial Total;Valor Actual Total; Perdida/Ganancia Total"
for i in $(cat valor_ini.count); do
        valorInicialTotal=$(bc <<< "scale=4; $(echo $i | tr ',' '.') + $(echo $valorInicialTotal | tr ',' '.')")
done
for i in $(cat valor_act.count); do
     valorActualTotal=$(bc <<< "scale=4; $(echo $i | tr ',' '.') + $(echo $valorActualTotal | tr ',' '.')")
done
perdidaGananciaTotal=$(bc <<< "scale=4; $(echo $valorActualTotal) - $(echo $valorInicialTotal)")
echo $cabecera2 >> ut2.table
echo "$valorInicialTotal;$valorActualTotal;$perdidaGananciaTotal" >> ut2.table
echo -ne "${redColour}"
printTable ';' "$(cat ut2.table)"
echo -ne "${endColour}"

rm ut.table 2>/dev/null
rm ut2.table 2>/dev/null
rm valor_ini.count valor_act.count 2>/dev/null

tput cnorm; exit 0
