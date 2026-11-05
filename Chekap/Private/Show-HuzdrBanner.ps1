function Show-HuzdrBanner {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'The banner is for the person at the console; it must never reach the pipeline.')]
    param(
        [ConsoleColor]$Primary   = 'Red',
        [ConsoleColor]$Secondary = 'Green',
        [ConsoleColor]$Signature = 'Green',
        [string]$Subtitle = ''
    )

    $art = @'
  .:.                    -*%@@@%**=.                  ---:.
 *@@@@%*:             :%@@@@@@@%:.+%#:                . .*#
 =@@@@@@@%*=:     :=*%@@@@#@@@@@.   :+*+=-        =*%@@= -=
 *#@@@@@@@@@@@%#+-=+*%@@@@+@@@@@:              .+%@@@@@% .
:+=*@@@@@@@@@%:      +@@@@-@@@@@              -@@@@@@@%*
*  .%@@@@@@@@*   ==%#=*@@@.@@@@%      :==**.  #@@@@@@@=
*+. .#@@@@@@@#+.*. #@@%@@@=-@@@+      .   :*: =@@@@##=
=++   .=#@@@@@+==   =****##..==             -   ::
+@@    -==*#%*:.*-:---
-@* :+           :+*+=+==.                          -:
.%# *:      -+:          =+-                        .*
 #@.++       .*%+*##+-     :-                       :*     -
 :@%%@.       :*%@@@@@@%*+##+=-----=+**+:   =-      #-    +*
  -@@@%.       *##%%#%%%*#*#@@@%#**+=:.:-***#.     +#   .#=
   .#@@%.       +@@@-@@@@#@%#+**%@#@@@@+%@@#      =#   =%:
     =%@%-      .%@+ =+*+:*##++##*-=+++.=@@:     +*   +#.
       +=%+       +:                     *.     *=   *#
          #%. -%= -                      - =#+ ::=  #*
           *% :@@+@#.-***.%@@#*@@@-+**= +@+@@=  +  #*
           -@* =%+@@@+@@@+**+=+=++*%@@*%@@*%+  *: #*
            #@ .+%*@@=#+==---------=*#=@@*#+   % +%
            #@+.@@%%%@%#****+**+*%%##%@@%%+   :% %.
            %@@=:#@@@*=:.- *@@%++-++--=++:    -% =
            #@@@%+::.-+#@**@@@@ =# =          #+
             +@@@@@@@@@@#@@@@@*  %##:       :#=
               -*#@@@@#: :##+. .+#=        :-
'@ -split "`r?`n"

    # r = primary (red), g = secondary (green), one char per column of $art
    $colors = @'
  grr                    gggrrrrrrrr                  rrrrr
 grrrrrrr             gggrrrrrrrrrrrrr                r rrr
 grrrrrrrrrrr     ggggrrrrrrrrrrr   rrrrrr        rrrrrr rr
 rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr              rrrrrrrrr r
rrrrrrrrrrrrrrr      rrrrrrrrrrr              rrrrrrrrrr
r  rrrrrrrrrrr   rrrrgrrrrrrrrrr      rrrrrr  rrrrrrrrr
rrr rrrrrrrrrrggrr rrrrrrrrrrrrr      r   rrr rrrrrrrr
rrr   rrrrrrrrggr   rrrrrrrrrrr             r   rr
rrr    rggggrgggrrrrrr
rrr gg           rrrgggrrr                          rr
rrr gg      ggr          rrr                        rr
 rrrgg       grrrrrrrr     rr                       rr     r
 rrrrgg       ggrrrrrrrrrrrrrrrrrrrrrrrrr   gg      rr    rr
  rrrrgg       ggggggggggggrrrrrrrrrrrgggggggg     rr   rrr
   rrrrgg       gggggggggggggggggggggggggggg      rr   rrr
     rrrgg      gggg ggggggggggggggggggggggg     rr   rrr
       rrrg       gg                     gg     rr   rr
          rrg ggg g                      g ggg rrr  rr
           rr ggggggggggggggggggggggggg gggggg  r  rr
           grr gggggggggggggggggggggggggggggg  rr rr
            gr ggggggggrrrrrrrrrrrrrrrrggggg   r rr
            grrggrrrrrrrrrrrrrrrrrrrrrrrrrr   rr rr
            grrrgggrrgggrr grrrrrrrrrrrrrr    rr r
            ggrrrrrgrrrrrrgrrrr rr r          rr
             ggrrrrrrrrrrrrrrrr  rrrr       rrr
               gggrrrrrr rrrrr rrrr        rr
'@ -split "`r?`n"

    $sig = @'
          __             __  __                __
         / /_  __  __   / / / /_  ______  ____/ /____
        / __ \/ / / /  / /_/ / / / /_  / / __  / ___/
       / /_/ / /_/ /  / __  / /_/ / / /_/ /_/ / /
      /_.___/\__, /  /_/ /_/\__,_/ /___/\__,_/_/
            /____/
'@ -split "`r?`n"

    Write-Host ''
    for ($i = 0; $i -lt $art.Count; $i++) {
        $line = $art[$i]; $map = $colors[$i]
        $j = 0
        while ($j -lt $line.Length) {
            $k = if ($j -lt $map.Length) { $map[$j] } else { ' ' }
            $n = $j
            while ($n -lt $line.Length -and (($(if ($n -lt $map.Length) { $map[$n] } else { ' ' })) -eq $k)) { $n++ }
            $chunk = $line.Substring($j, $n - $j)
            $fg = if ($k -eq 'g') { $Secondary } else { $Primary }
            Write-Host $chunk -NoNewline -ForegroundColor $fg
            $j = $n
        }
        Write-Host ''
    }
    Write-Host ''
    foreach ($l in $sig) { Write-Host $l -ForegroundColor $Signature }
    if ($Subtitle) {
        $pad = [Math]::Max(0, [int]((60 - $Subtitle.Length) / 2))
        Write-Host ''
        Write-Host ((' ' * $pad) + $Subtitle) -ForegroundColor DarkGray
    }
    Write-Host ''
}
