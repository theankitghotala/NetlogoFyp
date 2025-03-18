globals [
  tax-pool
  tax-rate
  tax-revenue
  reproduction-count
  culture-index-map
  fear-threshold
  w1
  w2
  gamma
  alpha
  beta
  money-of-dead
  ;lorenz-points
]

patches-own [ psugar max-psugar pspice max-pspice ]

turtles-own [
  sugar                   ; the amount of sugar this turtle has
  spice                   ; the amount of spice this turtle has
  sugar-metabolism        ; the amount of sugar that each turtles loses each tick
  spice-metabolism        ; the amount of spice that each turtles loses each tick
  vision                  ; the distance that this turtle can see in the horizontal and vertical directions
  ;vision-points           ; the points that this turtle can see in relative to it's current position (based on vision)
  age                     ; the current age of this turtle (in ticks)
  max-age                 ; the age at which this turtle will die of natural causes
  culture                   ;:::::::::::::::
  immune-system             ;:::::::::::::::
  aggression
  is-enemy?
  is-leader?                ;:::::::::::::::
  my-leader                 ;:::::::::::::::
  fear-level                ;; Affective state (neurocognitive fear)
  deliberative-score        ;; Rational assessment of a situation
  social-fear               ;; Fear spread from neighbors
  last-threat-intensity     ;; Stores last perceived threat level
  threat-exposure  ;; External stimulus affecting fear
  threat-level
]

to setup
  clear-all
  create-turtles initial-population [ setup-turtles ]
  setup-patches
  set tax-pool 0
  ;set tax-revenue 0
  set tax-rate 0.18
  set money-of-dead 0
  reset-ticks
end

to setup-turtles
    setxy random-xcor random-ycor
    set shape "person"
    set size 1.5
    set sugar 30 + random 10
    set spice 30 + random 10
    set sugar-metabolism one-of[1 2 3]
    set spice-metabolism one-of[1 2 3]
    set vision one-of[1 2 3 4 5]
    set age 10 + random 15
    set max-age 100 + random 20
    set culture n-values 4 [random 2]
    set is-leader? false
    set fear-level 0
    set threat-exposure 0
    set threat-level 0
    ;; turtles can look horizontally and vertically up to vision patches
    ;; but cannot look diagonally at all
;    set vision-points []
;    foreach (range 1 (vision + 1)) [ n ->
;    set vision-points sentence vision-points (list (list 0 n) (list n 0) (list 0 (- n)) (list (- n) 0))
;    ]
end

to setup-patches
;  file-open "sugar-map.txt"
;  foreach sort patches [ p ->
;    ask p [
;      set max-psugar file-read
;      set max-pspice file-read
;      set psugar max-psugar
;      set pspice max-pspice
;      recolor-patch
;    ]
;  ]
;  file-close
  ask patches[
    set max-psugar random max-sugar-level
    set psugar max-psugar
    set max-pspice random max-spice-level
    set pspice max-pspice
    recolor-patch
  ]
end

to recolor-patch
  set pcolor ( white - (( psugar + pspice) / 2 ) )
end

to setup-enemies
    if random-float 1 < 0.01 [ ;; 1% chance to be an enemy
      set is-enemy? true
      set shape "bug" ;; Mark enemies in red
    ]
    ;if is-enemy? = false [ set color green ] ;; Normal agents are green
end

to go
  if not any? turtles [stop]
  ask patches [
    patch-growback
    recolor-patch
  ]
  ask turtles [
    make-decision-for-movement
    consume-and-collect
    check-death
    ;update-label
    update-color        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    age-and-reproduce   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    trade               ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    pay-progressive-tax ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;interact-culture    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;engage-conflict     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;spread-disease      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;find-leader         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;assign-leaders      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    update-threat
    update-fear
    ;setup-enemies
  ]
  redistribute-tax
  calculate-gini
  update-population-plot
  update-reproduction-plot
  update-culture-plot
  ;update-lorenz-and-gini
  ;visualize-leadership
  tick
end

to make-decision-for-movement
  update-fear                 ;Neurocognitive (Affective) Module
  update-deliberation         ;Deliberative Module
  update-social-fear          ;Social Contagion of Fear Module

  if fear-level > deliberative-score [
    move-away-from-threat ;; If fear dominates, agent flees
  ]
  ifelse deliberative-score > fear-level and sugar < 2 [
    move-to-resource ;; If rational thought dominates, agent seeks food
  ]
  [
    move
  ]
end
to move
  let best-patch max-one-of patches in-radius vision [psugar + pspice]

  if best-patch != nobody and
     ([psugar] of best-patch + [pspice] of best-patch) > (psugar + pspice) [

     if not any? turtles-on best-patch [
       move-to best-patch
     ]
  ]
  ;; Check for conflict after moving
  if any? other turtles-on patch-here [
    resolve-conflict
  ]

end
to move-away-from-threat
  ;; Identify patches in vision range with lower fear influence
  let safe-patch max-one-of patches in-radius vision [psugar + pspice]

  if safe-patch != nobody [
    move-to safe-patch
  ]
end
to move-to-resource
  let best-resource-patch max-one-of patches in-radius vision [ psugar + pspice ]

  if best-resource-patch != nobody [
    move-to best-resource-patch
  ]

end
to resolve-conflict
  let opponents other turtles-on patch-here  ;; Exclude self from opponents list
  if any? opponents [
    let rival one-of opponents  ;; Pick a random rival

    let my-strength (sugar + spice)
    let rival-strength ([sugar] of rival + [spice] of rival)

    if my-strength > rival-strength [
      ;; Rival loses resources instead of dying
      ask rival [
        set sugar max list (sugar - 2) 0 ;; Loses up to 2 sugar
        set spice max list (spice - 2) 0 ;; Loses up to 2 spice
      ]
    ]
    if my-strength < rival-strength [
      ;; I lose resources and flee
      set sugar max list (sugar - 2) 0
      set spice max list (spice - 2) 0
      let safe-patch one-of patches with [not any? turtles-here]
      if safe-patch != nobody [
        move-to safe-patch
      ]
    ]
    ;; If strengths are equal, both lose small resources (stalemate)
    if my-strength = rival-strength [
      set sugar max list (sugar - 1) 0
      set spice max list (spice - 1) 0
      ask rival [
        set sugar max list (sugar - 1) 0
        set spice max list (spice - 1) 0
      ]
    ]
  ]
end
to consume-and-collect
  let p count turtles
  ;print ( p )
  ;; Consume sugar but ensure it never goes below zero
  set sugar max list (sugar - sugar-metabolism + max list psugar sugar-metabolism) 0
  set psugar max list ( (psugar - sugar-metabolism) / p ) 0  ;; Ensure psugar never goes negative

  ;; Consume spice similarly
  set spice max list (spice - spice-metabolism + max list pspice spice-metabolism) 0
  set pspice max list ( (pspice - spice-metabolism) / p ) 0  ;; Ensure pspice never goes negative
end
to check-death
  if sugar <= 0 or spice <= 0 [
    ;; Instead of dying immediately, reduce metabolism & weaken agent
    set sugar-metabolism max list (sugar-metabolism - 1) 1
    set spice-metabolism max list (spice-metabolism - 1) 1

    ;; Reduce vision due to weakness
    ;set vision max list (vision - 1) 1

    ;; Mark turtle as "injured" (optional, for visualization)
    if color != red [ set size 4 ]  ;; Prevents constant resetting of color

    ;; If metabolism is at minimum AND agent still has 0 sugar/spice, they die
    if (sugar-metabolism = 1 and spice-metabolism = 1) and (sugar <= 0 or spice <= 0) [
      die
    ]
  ]
end
to update-label
  let int-sugar round sugar
  set label int-sugar
end

to patch-growback
  ;; Sugar grows back at different rates based on fertility
    set psugar min list (psugar + random 2) max-psugar

  ;; Spice grows back at different rates based on fertility
    set pspice min list (pspice + random 2) max-pspice
end

;////////////////////////////////////////////////// AGE REPRODUCTION AND PLOT /////////////////////////////////////////////////////////

to age-and-reproduce
  ;; Age the agent
  set age age + 1

  ;; If the agent reaches max-age, it dies
  if age >= max-age [
    die
    set money-of-dead money-of-dead + sugar + spice
    set tax-pool tax-pool + money-of-dead
    ;print ( word "Dead man contributed : " money-of-dead " amount of money. " )
  ]

  ;; Reproduction condition: only mature agents (age 15+) with enough resources can reproduce
  if age >= reproduction-age and sugar >= 50 and spice >= 50 [

    ;; Hatch a child with inherited traits and slight mutations
    hatch 1 [
      set sugar sugar * 0.75  ;; Child gets three fourth of the parent's sugar
      set spice spice * 0.75  ;; Child gets three fourth of the parent's spice
      set sugar-metabolism max (list 1 (sugar-metabolism + one-of [0 1]))
      set spice-metabolism max (list 1 (spice-metabolism + one-of [0 1]))


      set vision 3 + random 3  ;; Randomize vision

      set age 0  ;; Newborn starts at age 0
      set max-age 100 + random 40

      ;set color red  ;; (Optional) Mark newborns as red
      set fear-level 0
      set threat-exposure 0
    ]

    ;; Parent keeps the remaining half of resources
    set sugar sugar * 0.75
    set spice spice * 0.75
    set reproduction-count reproduction-count + 1
  ]
end

to update-population-plot
  set-current-plot "Population Over Time"
  set-current-plot-pen "Population"
end
to update-reproduction-plot
  set-current-plot "Reproduction Count"
  set-current-plot-pen "Reproduction"
end


;to update-lorenz-and-gini
;;  let num-people count turtles
;;  let sorted-wealths sort [sugar] of turtles
;  let wealth-sum-so-far 0
;  let total-wealth-values [sugar + spice] of turtles
;;  let total-wealth sum sorted-wealths
;;  let wealth-sum-so-far 0
;  let index 0
;;  set gini-index-reserve 0
;  set lorenz-points []
;;  repeat num-people [
;;    set wealth-sum-so-far (wealth-sum-so-far + item index sorted-wealths)
;    set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
;    set index (index + 1)
;;    set gini-index-reserve
;;      gini-index-reserve +
;;      (index / num-people) -
;;      (wealth-sum-so-far / total-wealth)
;;  ]
;end
;//////////////////////////////////////////////// GINI COEFF. ////////////////////////////////////////////////////////////////////////

to calculate-gini
  if count turtles = 0 [ stop ]  ;; Avoid errors when no turtles exist

  let sugar-values [sugar] of turtles
  let spice-values [spice] of turtles
  let total-wealth-values [sugar + spice] of turtles

  let sugar-gini compute-gini sugar-values
  let spice-gini compute-gini spice-values
  let total-gini compute-gini total-wealth-values

  set-current-plot "Gini Coefficient"
  ;clear-plot  ;; Ensure we don't overlap previous values

  ;; Plot for sugar values
  set-current-plot-pen "Sugar"
  plot sugar-gini

  ;; Plot for spice values
  set-current-plot-pen "Spice"
  plot spice-gini

  ;; Plot for total wealth values
  set-current-plot-pen "Total Wealth"
  plot total-gini
end

to-report compute-gini [values]
  let n length values
  if n = 0 [ report 0 ]  ;; No data, Gini is 0
  if n = 1 [ report 0 ]  ;; If only one agent, no inequality (Gini = 0)

  let sorted-values sort values
  let total sum sorted-values
  if total = 0 [ report 0 ]  ;; No wealth, Gini is 0

  ;; Improved formula for Gini coefficient calculation
  let sum-diff 0
  let i 1
  foreach sorted-values [ [val] ->
    set sum-diff sum-diff + (2 * i - n - 1) * val
    set i i + 1
  ]

  let gini sum-diff / (n * total)
  report gini
end

;////////////////////////////////////////////////// TRADE AND TAX /////////////////////////////////////////////////////////////////////

to trade
  let neighbor one-of turtles in-radius 5
  if neighbor != nobody [

    ;; Define needs and excess
    let sugar-lf sugar / sugar-metabolism
    let spice-lf spice / spice-metabolism

    let neighbor-sugar-lf [sugar] of neighbor / [sugar-metabolism] of neighbor
    let neighbor-spice-lf [spice] of neighbor / [spice-metabolism] of neighbor

    let net-metabolism sugar-metabolism + spice-metabolism
    let net-neighbor-metabolism ( [sugar-metabolism] of neighbor + [spice-metabolism] of neighbor )

    let sumsp sugar * spice-metabolism
    let spmsu spice * sugar-metabolism

    let neighbor-sumsp [sugar] of neighbor * [spice-metabolism] of neighbor
    let neighbor-spmsu [spice] of neighbor * [sugar-metabolism] of neighbor

    ;; Only trade if both parties have an excess
    if ( sugar-lf > spice-lf and neighbor-sugar-lf < neighbor-spice-lf )
    [
      let trade-amount min (list ((sumsp - spmsu) / net-metabolism )  ((neighbor-spmsu - neighbor-sumsp) / net-neighbor-metabolism))
      set sugar sugar - trade-amount
      ask neighbor [ set sugar sugar + trade-amount ]
      ;print (word "Trade happened: Agent gave " trade-amount " sugar to neighbor.")
   ]

    ifelse (sugar-lf < spice-lf and neighbor-sugar-lf > neighbor-spice-lf )
    [
      let trade-amount min ( list ((spmsu - sumsp) / net-metabolism)  ( (neighbor-sumsp - neighbor-spmsu) / net-neighbor-metabolism))
      set sugar sugar + trade-amount
      ask neighbor [set sugar sugar - trade-amount ]
      ;print (word "Trade happened: Agent received " trade-amount " sugar from neighbor.")
   ]
    [
      ;print "No trade occurred."
    ]

  ]
end

to pay-progressive-tax

  if sugar > 100 [ set tax-rate 0.5 ]
  if sugar > 75 and sugar <= 100 [ set tax-rate 0.3 ]
  if sugar > 50 and sugar <= 75 [ set tax-rate 0.2 ]
  if sugar > 30 and sugar <= 50 [ set tax-rate 0.1 ]

  let tax-amount sugar * tax-rate
  set sugar sugar - tax-amount
  set tax-pool tax-pool + tax-amount
end

to redistribute-tax
  if any? turtles and tax-pool > 0 [  ;; Ensure there are turtles and available taxes
    let sorted-turtles sort-by [[a b] -> [sugar] of a < [sugar] of b] turtles  ;; Sort by wealth (ascending)

    let sorted-agentset turtle-set sorted-turtles  ;; Convert list to agentset

    let num-poor count turtles with [sugar < 10]
    let num-middle count turtles with [sugar >= 10 and sugar < 30]

    let total-recipients num-poor + num-middle

    if total-recipients > 0 [
      let share tax-pool / total-recipients  ;; Fair share per recipient

      ask sorted-agentset [
        if sugar < 10 [
          let bonus share * 2  ;; Poorest get more
          set sugar sugar + min (list bonus tax-pool)  ;; Prevent overdrawing tax-pool
          set tax-pool tax-pool - min (list bonus tax-pool)
        ]
        if sugar >= 10 and sugar < 30 [
          let normal-share share  ;; Normal distribution
          set sugar sugar + min (list normal-share tax-pool)
          set tax-pool tax-pool - min (list normal-share tax-pool)
        ]
        if tax-pool <= 0 [ stop ]  ;; Stop if funds run out
      ]
    ]
  ]
end

;//////////////////////////////////////////////////  Culture and Plot  ////////////////////////////////////////////////////////////////

to interact-culture
  let nearby-turtles turtles-on patches in-radius vision  ;; Get neighboring agents
  if any? nearby-turtles [
    let partner one-of nearby-turtles  ;; Pick a random neighbor

    ;; Ensure both agents have cultures of the same length
    if length culture = length [culture] of partner [
      let differing-traits filter [ i -> (item i culture) != (item i [culture] of partner)] (range length culture)

      if not empty? differing-traits [
        let trait-to-change one-of differing-traits

        ;; Introduce a small probability of cultural resistance (e.g., 80% chance to adopt)
        let adoption-chance 0.1
        if random-float 1 < adoption-chance [
          set culture replace-item trait-to-change culture (item trait-to-change [culture] of partner)
        ]
      ]
    ]
  ]
end

to engage-conflict
  let neighbor one-of other turtles in-radius 2  ;; Exclude self
  if neighbor != nobody [
    let differing-traits filter [i -> (item i culture) != (item i [culture] of neighbor)] (range length culture)

    ;; Use length instead of count
    let cultural-diff length differing-traits

    ;; Prevent division by zero
    let culture-length length culture
    if culture-length > 0 [
      let conflict-chance aggression * cultural-diff / culture-length

      if random-float 1 < conflict-chance [
        ifelse aggression > [aggression] of neighbor [
          ask neighbor [ die ] ;; Stronger agent wins
        ][
          die ;; Weaker agent loses
        ]
      ]
    ]
  ]
  if fear-level < 0.5 [  ;; Only attack if fear is low
    let opponent one-of turtles in-radius 1
    if opponent != nobody and [fear-level] of opponent < 0.5 [
      ask opponent [die]  ;; Attack and remove opponent
    ]
  ]
end

to setup-culture-index
  set culture-index-map []
end

to-report culture-label [agent]
  let traits [culture] of agent  ;; Extract agent's culture list
  report (word (item 0 traits) "-" (item 1 traits) "-" (item 2 traits))  ;; String format
end

to-report get-culture-index [culture-name]
  let culture-name-str (word culture-name "")  ;; Convert to string

  ;; Ensure culture-index-map is initialized as a list
  if not is-list? culture-index-map [
    set culture-index-map []
  ]

  if not member? culture-name-str culture-index-map [
    set culture-index-map lput culture-name-str culture-index-map
  ]

  report position culture-name-str culture-index-map
end

to update-culture-plot
  set-current-plot "Culture Distribution"
  clear-plot  ;; Clears previous data for smooth updates

  let unique-cultures remove-duplicates [culture-label self] of turtles

  foreach unique-cultures [ c ->
    let count-culture count turtles with [ culture-label self = c ]
    let culture-num get-culture-index c  ;; Get numeric index of the culture

    ;; Create or select a unique pen for each culture
    create-temporary-plot-pen (word "Culture-" culture-num)
    set-plot-pen-mode 1  ;; Set to bar mode
    set-plot-pen-color (5 + (culture-num * 20)) mod 140  ;; Assign unique colors
    plotxy culture-num count-culture  ;; Plot the data
  ]
end

;to update-culture-colorf
;  let culture-sum sum culture  ;; Sum of cultural traits
;  set color scale-color red culture-sum 10 0  ;; Dynamically assign colors
;end

;///////////////////////////////////////////////////       Disease    ///////////////////////////////////////////////////////////////

to spread-disease
  ;; Disease spread mechanics
    if random-float 1 < 0.01 [ ;; 1% chance per tick to get infected randomly
      become-infected
      set shape "circle"
    ]

    ;; Infected agents have a chance to spread the disease
    if color = black [
      let neighbours turtles in-radius 1
      ask neighbours [
        if random-float 1 < 0.002 [ ;; 20% chance per tick for nearby turtles to get infected
          become-infected
        ]
      ]

      ;; Small chance of natural recovery
      if random-float 1 < 0.5 [ ;; 0.5% chance per tick to recover
        recover
      ]
    ]
end

to become-infected
  ;set color black  ;; Infected agents turn black
  set shape "square"
  set sugar-metabolism sugar-metabolism * 1.3  ;; Increased metabolism due to disease
  set spice-metabolism spice-metabolism * 1.3
  set immune-system immune-system - 1  ;; Weaken immunity over time
end

to recover
  set color green  ;; Recovered agents turn green
  set shape "person"
  set sugar-metabolism sugar-metabolism * 0.8  ;; Regain normal metabolism
  set spice-metabolism spice-metabolism * 0.8
  set immune-system immune-system + 2  ;; Gain some immunity boost after recovery
end

;//////////////////////////////////////////////////// LEADERSHIP /////////////////////////////////////////////////////////////////////

to find-leader
  if my-leader = nobody [  ;; Only assign a leader if not already assigned
    let potential-leader one-of turtles with [
      is-leader? = true and count link-neighbors < 5
    ]

    if potential-leader != nobody [
      set my-leader potential-leader
      create-link-with my-leader [ set color black ]
    ]
  ]
end

to assign-leaders
  if my-leader = nobody [  ;; Ensure follower doesn't change leaders
    let potential-leader one-of turtles in-radius 5 with [
      is-leader? = true and count link-neighbors < 5
    ]

    if potential-leader != nobody [
      set my-leader potential-leader
      set is-leader? false  ;; This turtle is now a follower
      create-link-with my-leader [ set color black ]
    ]
  ]
end

;to visualize-leadership
;  ask turtles [
;    if my-leader != nobody and my-leader != self and not link-neighbor? my-leader [
;      create-link-with my-leader [ set color black ]
;    ]
;  ]
;end


to update-threat
  ;; Measure nearby threats
  let predator-threat count turtles in-radius 3 with [aggression > 0.7]  ;; Aggressive agents
  let scarcity-threat ifelse-value (psugar + pspice < 2) [1] [0]  ;; If resources are low
  let disease-threat count turtles in-radius 3 with [shape = "square"]  ;; Count nearby infected agents

  ;; Combine these into an overall threat level
  set threat-level (predator-threat * 0.5) + (scarcity-threat * 0.3) + (disease-threat * 0.2)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 1. Neurocognitive (Affective) Module ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to update-fear
  let threat-intensity perceived-threat
  set last-threat-intensity threat-intensity
  set fear-level max (list 0 (fear-level + (alpha * threat-intensity) - (beta * fear-decay-rate)))
end
to-report perceived-threat
  ;let nearby-enemies turtles with [shape = "bug"] in-radius 3  ;; Example: red turtles are enemies
  let nearby-enemies count turtles with [is-enemy? = true] in-radius 3
  let resource-scarcity 1 / (1 + (psugar + pspice)) ;; Higher scarcity = higher threat
  report (nearby-enemies * 2 + resource-scarcity * 3)  ;; Weighted threat calculation
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 2. Deliberative Module ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to update-deliberation
  let reward-value resource-reward
  set deliberative-score (w1 * reward-value) - (w2 * fear-level)
end
to-report resource-reward
  report psugar + pspice  ;; More resources = higher rational reward
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 3. Social Contagion of Fear Module ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to update-social-fear
  let avg-neighbor-fear mean [fear-level] of turtles in-radius 3
  set social-fear gamma * avg-neighbor-fear
  set fear-level fear-level + social-fear  ;; Fear spreads socially
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Decision-Making Process ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;to make-decision-for-movement
;  update-fear
;  update-deliberation
;  update-social-fear
;
;  if fear-level > deliberative-score [
;    move-away-from-threat ;; If fear dominates, agent flees
;  ]
;  ifelse deliberative-score > fear-level and sugar < 2 [
;    move-to-resource ;; If rational thought dominates, agent seeks food
;  ]
;  [
;    move
;  ]
;end


to update-color
  if fear-level > 0.8 [ set color red ]  ;; Extreme fear (running away)
  if fear-level > 0.5 [ set color orange ]  ;; Moderate fear
  if fear-level > 0.2 [ set color blue ]  ;; Mild fear
  if fear-level <= 0.2 [ set color green ]  ;; No fear
end





;//END OF THE CODE
@#$#@#$#@
GRAPHICS-WINDOW
246
10
663
428
-1
-1
12.4
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
1
1
1
ticks
30.0

BUTTON
10
10
73
43
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
78
10
141
43
Go
go\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
712
10
1263
433
Legend:\n- Green Agents → High sugar\n- Orange Agents → Medium sugar\n- Red Agents → Low sugar (near death)\n- Bright Yellow Patches → High sugar patches\n- Dark Yellow Patches → Low sugar patches\n\nThe Gini coefficient is a measure of inequality, ranging from 0 (perfect equality) to 1 (maximum inequality).\n\nCulture Colors:\nBlue    → Culture Sum = 0\nCyan    → Culture Sum = 1\nMagenta → Culture Sum = 2\nYellow  → Culture Sum = 3\nPink   → Culture Sum = 4\n\nif fear-level > 0.8 red => Extreme fear (running away)\nif fear-level > 0.5 orange => Moderate fear\nif fear-level > 0.2 yellow => Mild fear\nif fear-level <= 0.2 green => No fear\n
15
40.0
1

BUTTON
146
10
235
43
Go Forever
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
937
170
1192
320
Gini Coefficient
Time
Gini Coefficient
0.0
10.0
0.0
0.5
true
true
"" ""
PENS
"Spice" 1.0 0 -2674135 true "" "plot sugar-gini"
"sugar" 1.0 0 -955883 true "" "plot spice-gini"
"Total Wealth" 1.0 0 -6459832 true "" "plot total-gini"

PLOT
14
380
214
530
Population Over Time
Time
Population
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"population" 1.0 0 -8990512 true "" "plot count turtles"

PLOT
1148
170
1348
320
Culture Distribution
Time
population
0.0
10.0
0.0
10.0
true
true
"" ""
PENS

PLOT
13
229
213
379
Reproduction Count
Culture Index
Population reproduced
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Reproduction" 1.0 0 -16777216 true "" "plot reproduction-count"

SLIDER
11
83
183
116
max-sugar-level
max-sugar-level
0
100
13.0
1
1
NIL
HORIZONTAL

SLIDER
11
117
183
150
max-spice-level
max-spice-level
0
100
11.0
1
1
NIL
HORIZONTAL

SLIDER
11
152
183
185
Reproduction-age
Reproduction-age
0
100
41.0
1
1
NIL
HORIZONTAL

SLIDER
11
186
183
219
fear-decay-rate
fear-decay-rate
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
11
50
183
83
initial-population
initial-population
0
1000
80.0
10
1
NIL
HORIZONTAL

PLOT
1147
324
1347
474
Lorenz curve
Pop %
Wealth %
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"equal" 1.0 0 -16777216 true "" ""
"lorenz" 1.0 0 -5298144 true "" "plot-pen-reset\nset-plot-pen-interval 100 / count turtles\nplot 0\nforeach lorenz-points plot"

@#$#@#$#@
## WHAT IS IT?

This model is an agent-based simulation inspired by Growing Artificial Societies by Epstein & Axtell. It explores how autonomous agents interact in a dynamic environment by gathering resources, trading, forming social structures, paying taxes, and evolving over time. The model helps analyze economic disparity, wealth distribution, cultural diffusion, conflict, and governance.

## HOW IT WORKS

-The environment consists of patches containing sugar and spices, which regenerate over time.
-Agents (turtles) move based on their vision and resource needs, consuming sugar and spices for survival.
-Agents have metabolism rates, vision ranges, cultural traits, and aggression levels.
-Trading occurs between agents based on resource scarcity and surplus.
-Leaders emerge, forming hierarchical structures where followers pay taxes.
-Conflict and migration arise due to resource competition and environmental changes.
-Over time, mutations in vision, metabolism, and culture influence agent behavior.

## HOW TO USE IT

-Press Setup to initialize the environment and place agents.
-Press Go to start the simulation.
-Adjust parameters such as initial-population, tax-rate, and trade-ratio to explore different scenarios.
-Observe the Gini coefficient graph to analyze wealth inequality.
-Use the network visualization to explore trade and leadership structures.

## THINGS TO NOTICE

-How do wealth and resources distribute over time?
-How does taxation affect economic disparity?
-Do leaders emerge and maintain power, or does leadership shift frequently?
-How do migration and conflict influence agent survival?

## THINGS TO TRY
-Increase or decrease taxation and observe its impact.
-Modify trade ratios to see how economies stabilize or collapse.
-Introduce a pandemic scenario by adjusting disease parameters.

## EXTENDING THE MODEL

-Introduce advanced governance mechanisms, such as policy-driven taxation.
-Implement different leadership styles, such as democratic elections or autocratic rule.
-Expand cultural evolution dynamics, allowing dominant cultures to emerge.

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

-Based on Growing Artificial Societies: Social Science from the Bottom Up by Epstein & Axtell.
-Inspired by economic models in NetLogo and complex adaptive system studies.
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
