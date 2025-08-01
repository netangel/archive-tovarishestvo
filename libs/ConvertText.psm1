﻿$Translit = @{
    [char]'à' = "a"
    [char]'À' = "A"
    [char]'á' = "b"
    [char]'Á' = "B"
    [char]'â' = "v"
    [char]'Â' = "V"
    [char]'ã' = "g"
    [char]'Ã' = "G"
    [char]'ä' = "d"
    [char]'Ä' = "D"
    [char]'å' = "e"
    [char]'Å' = "E"
    [char]'¸' = "e"
    [char]'¨' = "E"
    [char]'æ' = "zh"
    [char]'Æ' = "Zh"
    [char]'ç' = "z"
    [char]'Ç' = "Z"
    [char]'è' = "i"
    [char]'È' = "I"
    [char]'é' = "y"
    [char]'É' = "Y"
    [char]'ê' = "k"
    [char]'Ê' = "K"
    [char]'ë' = "l"
    [char]'Ë' = "L"
    [char]'ì' = "m"
    [char]'Ì' = "M"
    [char]'í' = "n"
    [char]'Í' = "N"
    [char]'î' = "o"
    [char]'Î' = "O"
    [char]'ï' = "p"
    [char]'Ï' = "P"
    [char]'ð' = "r"
    [char]'Ð' = "R"
    [char]'ñ' = "s"
    [char]'Ñ' = "S"
    [char]'ò' = "t"
    [char]'Ò' = "T"
    [char]'ó' = "u"
    [char]'Ó' = "U"
    [char]'ô' = "f"
    [char]'Ô' = "F"
    [char]'õ' = "kh"
    [char]'Õ' = "Kh"
    [char]'ö' = "ts"
    [char]'Ö' = "Ts"
    [char]'÷' = "ch"
    [char]'×' = "Ch"
    [char]'ø' = "sh"
    [char]'Ø' = "Sh"
    [char]'ù' = "sch"
    [char]'Ù' = "Sch"
    [char]'ú' = ""
    [char]'Ú' = ""
    [char]'û' = "y"
    [char]'Û' = "Y"
    [char]'ü' = ""
    [char]'Ü' = ""
    [char]'ý' = "e"
    [char]'Ý' = "E"
    [char]'þ' = "yu"
    [char]'Þ' = "Yu"
    [char]'ÿ' = "ya"
    [char]'ß' = "Ya"
    [char]' ' = ""
    [char]'¹' = "N"
    [char]',' = "_"
    [char]'.' = "_"
    [char]'а' = "a"
    [char]'А' = "A"
    [char]'б' = "b"
    [char]'Б' = "B"
    [char]'в' = "v"
    [char]'В' = "V"
    [char]'г' = "g"
    [char]'Г' = "G"
    [char]'д' = "d"
    [char]'Д' = "D"
    [char]'е' = "e"
    [char]'Е' = "E"
    [char]'ё' = "e"
    [char]'Ё' = "E"
    [char]'ж' = "zh"
    [char]'Ж' = "Zh"
    [char]'з' = "z"
    [char]'З' = "Z"
    [char]'и' = "i"
    [char]'И' = "I"
    [char]'й' = "y"
    [char]'Й' = "Y"
    [char]'к' = "k"
    [char]'К' = "K"
    [char]'л' = "l"
    [char]'Л' = "L"
    [char]'м' = "m"
    [char]'М' = "M"
    [char]'н' = "n"
    [char]'Н' = "N"
    [char]'о' = "o"
    [char]'О' = "O"
    [char]'п' = "p"
    [char]'П' = "P"
    [char]'р' = "r"
    [char]'Р' = "R"
    [char]'с' = "s"
    [char]'С' = "S"
    [char]'т' = "t"
    [char]'Т' = "T"
    [char]'у' = "u"
    [char]'У' = "U"
    [char]'ф' = "f"
    [char]'Ф' = "F"
    [char]'х' = "kh"
    [char]'Х' = "Kh"
    [char]'ц' = "ts"
    [char]'Ц' = "Ts"
    [char]'ч' = "ch"
    [char]'Ч' = "Ch"
    [char]'ш' = "sh"
    [char]'Ш' = "Sh"
    [char]'щ' = "sch"
    [char]'Щ' = "Sch"
    [char]'ь' = ""
    [char]'Ь' = ""
    [char]'ы' = "y"
    [char]'Ы' = "Y"
    [char]'ъ' = ""
    [char]'Ъ' = ""
    [char]'э' = "e"
    [char]'Э' = "E"
    [char]'ю' = "yu"
    [char]'Ю' = "Yu"
    [char]'я' = "ya"
    [char]'Я' = "Ya"
    [char]'№' = "N"
}

Function ConvertTo-Translit {
    Param (
        [string] $InputString
    )

    # Сначала обрабатываем случаи с комбинированными символами
    # Заменяем и + объединённое бреве (U+0306) на стандартное й
    $normalizedInput = $InputString -replace "и$([char]0x0306)", 'й'
    $normalizedInput = $normalizedInput -replace "И$([char]0x0306)", 'Й'
    # Заменяем е + объединённое умляут (U+0308) на стандартное ё  
    $normalizedInput = $normalizedInput -replace "е$([char]0x0308)", 'ё'
    $normalizedInput = $normalizedInput -replace "Е$([char]0x0308)", 'Ё'

    $Result = ''

    foreach ($c in $normalizedInput.ToCharArray())
    {
        if ($Null -cne $Translit[$c] ) {
            $Result += $Translit[$c]
        }
        else {
            $Result += $c
        }
    }
    
    return $Result -replace '[^\x20-\x7E]', ''
}

Export-ModuleMember -Function ConvertTo-Translit
