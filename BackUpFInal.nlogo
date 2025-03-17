patches-own [
  psugar
  max-psugar
  pspice
  max-pspice
]
turtles-own [
  sugar
  spice
  sugar-metabolism
  spice-metabolism
  vision
  vision-points
  sex
  age
  max-age
  culture
  group-id
  aggression
]
globals [
  tax-pool
]
to setup
  clear-all
  set tax-pool 0
  setup-patches
  setup-turtles
  ;;setup-gini-graph
  reset-ticks
end
to setup-patches
  ask patches[
    set max-psugar one-of[0 1 2 3 4 5]
    set psugar max-psugar
    set max-pspice one-of[0 1 2 3 4 5]
    set pspice max-pspice
    recolor-patch
  ]
end
to setup-turtles
  create-turtles 50[
    setxy random-xcor random-ycor
    set color red
    set shape "square"
    set sugar random 20 + 10
    set sugar-metabolism one-of[0 1 2 3 4 5]
    set spice 30 + random 30
    set spice-metabolism one-of[0 1 2 3 4 5]
    set vision one-of[0 1 2 3 4 5]
    set age random 10
    set max-age 60 + random 40
    set culture n-values 4 [random 2]
  ]
end
to go
  if not any? turtles [stop]
  ask turtles [ move eat check-death update-label update-color age-and-reproduce trade pay-progressive-tax interact-culture spread-disease ]
  ask patches [ patch-growback recolor-patch ]
  redistribute-tax
  calculate-gini
  tick
end
to move
  let best-patch max-one-of patches in-radius vision [psugar + pspice]
  if best-patch != nobody and (psugar + pspice) < ([psugar] of best-patch + [pspice] of best-patch) [
     move-to best-patch
  ]
  resolve-conflict
end
to eat
  set sugar (sugar - sugar-metabolism + psugar)
  set psugar 0
  set spice (spice - spice-metabolism + pspice)
  set pspice 0
end
to check-death
  if sugar <= 0 or spice <= 0 [die]
end
to recolor-patch
  set pcolor (white - psugar)  ;; More sugar = brighter
end
to update-label
  set label sugar
end
to update-color
  let culture-sum sum culture
  if culture-sum = 0 [ set color blue ]
  if culture-sum = 1 [ set color cyan ]
  if culture-sum = 2 [ set color magenta ]
  if culture-sum = 3 [ set color yellow ]
  if culture-sum = 4 [ set color pink ]
end
to patch-growback
  if psugar < max-psugar [ set psugar psugar + 1 ]
  if pspice < max-pspice [ set pspice pspice + 1 ]
end
to age-and-reproduce
  set age age + 1
  if age >= max-age [ die ]  ;; Agents die of old age
  if age >= 15 [
    if sugar >= 30 and spice >= 20 [
    hatch 1 [
      set sugar sugar / 2
      set spice spice / 2
      set sugar-metabolism sugar-metabolism + one-of [-1 0 1]
      set spice-metabolism spice-metabolism + one-of [-1 0 1]
      set vision 1 + random 5
      set age 0
      set max-age max (list 20 (max-age + one-of [-5 0 5]))
      set color red
    ]
    set sugar sugar / 2
  ]
  ]
end
to calculate-gini
  let sugar-values [sugar] of turtles
  let spice-values [spice] of turtles
  let total-wealth-values [sugar + spice] of turtles


  let sugar-gini compute-gini sugar-values
  let spice-gini compute-gini spice-values
  let total-gini compute-gini total-wealth-values

  set-current-plot "Gini Coefficient"
  set-current-plot-pen "Sugar"
  plot sugar-gini

  set-current-plot-pen "Spice"
  plot spice-gini

  set-current-plot-pen "Total Wealth"
  plot total-gini
end
to-report compute-gini [values]
  if length values = 0 [ report 0 ]

  let sorted-values sort values
  let n length sorted-values
  let total sum sorted-values
  if total = 0 [ report 0 ]  ;; Avoid division by zero

  let cumulative-sum 0
  let weighted-sum 0

  ;; Calculate cumulative weighted sum
  (foreach sorted-values [val ->
    set cumulative-sum cumulative-sum + val
    set weighted-sum weighted-sum + cumulative-sum
  ])

  ;; Compute Gini coefficient using the correct formula
  let gini (2 * weighted-sum) / (n * total) - (n + 1) / n
  report gini
end
to trade
  let neighbor one-of turtles in-radius 2
  if neighbor != nobody [

    ;; Determine excess and need for sugar
    let my-sugar-need sugar-metabolism * 2
    let neighbor-sugar-need [sugar-metabolism] of neighbor * 2
    let my-excess-sugar max list (sugar - my-sugar-need) 0
    let neighbor-excess-sugar max list ([sugar] of neighbor - neighbor-sugar-need) 0

    ;; Determine excess and need for spice
    let my-spice-need spice-metabolism * 2
    let neighbor-spice-need [spice-metabolism] of neighbor * 2
    let my-excess-spice max list (spice - my-spice-need) 0
    let neighbor-excess-spice max list ([spice] of neighbor - neighbor-spice-need) 0

    ;; Direct sugar-to-sugar trade (same as before)
    if (my-excess-sugar > 0 and [sugar] of neighbor < neighbor-sugar-need) [
      let trade-amount min (list my-excess-sugar (neighbor-sugar-need - [sugar] of neighbor))
      set sugar sugar - trade-amount
      ask neighbor [ set sugar sugar + trade-amount ]
    ]

    ;; Direct spice-to-spice trade (same as before)
    if (my-excess-spice > 0 and [spice] of neighbor < neighbor-spice-need) [
      let trade-amount min (list my-excess-spice (neighbor-spice-need - [spice] of neighbor))
      set spice spice - trade-amount
      ask neighbor [ set spice spice + trade-amount ]
    ]

    ;; Bartering: trade sugar for spice
    if (my-excess-sugar > 0 and neighbor-excess-spice > 0) [
      let trade-amount min (list my-excess-sugar neighbor-excess-spice)
      set sugar sugar - trade-amount
      set spice spice + trade-amount
      ask neighbor [
        set sugar sugar + trade-amount
        set spice spice - trade-amount
      ]
    ]

    ;; Bartering: trade spice for sugar
    if (my-excess-spice > 0 and neighbor-excess-sugar > 0) [
      let trade-amount min (list my-excess-spice neighbor-excess-sugar)
      set spice spice - trade-amount
      set sugar sugar + trade-amount
      ask neighbor [
        set spice spice + trade-amount
        set sugar sugar - trade-amount
      ]
    ]
  ]
end
to pay-progressive-tax
  let tax-rate 0.1
  if sugar > 30 [ set tax-rate 0.2 ]
  if sugar > 50 [ set tax-rate 0.3 ]

  let tax-amount sugar * tax-rate
  set sugar sugar - tax-amount
  set tax-pool tax-pool + tax-amount

end
to redistribute-tax
  if any? turtles and tax-pool > 0 [  ;; Only redistribute if there are turtles and taxes available
    let sorted-turtles sort-by [[a b] -> [sugar] of a < [sugar] of b] turtles
    let agentset-sorted turtle-set sorted-turtles  ;; Convert list to agentset

    ask agentset-sorted [
      if sugar < 10 [ set sugar sugar + (tax-pool / count turtles) * 2 ]  ;; Give more to the poorest
      if sugar >= 10 and sugar < 30 [ set sugar sugar + (tax-pool / count turtles) ]  ;; Normal distribution
    ]

    set tax-pool 0  ;; Reset tax pool after redistribution
  ]
end
to interact-culture
  let nearby-turtles turtles-on patches in-radius vision  ;; Get neighboring agents
  if any? nearby-turtles [
    let partner one-of nearby-turtles
    let differing-traits filter [ i -> (item i culture) != (item i [culture] of partner)] (range length culture)
    if not empty? differing-traits [
      let trait-to-change one-of differing-traits
      set culture replace-item trait-to-change culture (item trait-to-change [culture] of partner)
    ]
  ]
end
;to engage-conflict
;  let neighbor one-of turtles in-radius 2
;  if neighbor != nobody [
;    let cultural-diff count (filter [i -> item i culture != item i [culture] of neighbor] range length culture)
;    let conflict-chance aggression * cultural-diff / length culture
;    if random-float 1 < conflict-chance [
;      ifelse aggression > [aggression] of neighbor [
;        ask neighbor [ die ] ;; Stronger agent wins
;      ][
;        die ;; Weaker agent loses
;      ]
;    ]
;  ]
;end
to resolve-conflict
  let opponents turtles-on patch-here
  if any? opponents [
    let rival one-of opponents
    if rival != nobody [
      let my-strength sugar + spice
      let rival-strength [sugar] of rival + [spice] of rival

      if my-strength > rival-strength [
        ask rival [ die ] ;; I win, opponent dies
      ]
      if my-strength < rival-strength [
        move-to one-of patches with [not any? turtles-here] ;; I move away
      ]
      ;; If strengths are equal, do nothing (stalemate)
    ]
  ]
end
to spread-disease
    if random-float 1 < 0.01 [ ;; 1% chance per tick to get infected
      set color black ;; Infected agents turn blue
      set sugar-metabolism sugar-metabolism * 1.2
      set spice-metabolism spice-metabolism * 1.2
    ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
