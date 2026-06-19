/// Pre-canned demo Q&A for the onboarding "See how it works" taste. Each entry
/// is (question, answer, examInsight) — the examInsight mirrors the real chat's
/// "How this is tested" section (how it's tested + common errors + tricks),
/// grounded in how each topic actually appears in our prelim corpus. Rendered
/// instantly with NO backend call (no API cost, no clarifying questions, no
/// typing). Keyed by subject; falls back to generic.
const demoQA = <String, List<(String, String, String)>>{
  'Chemistry': [
    (
      "Explain Le Chatelier's principle",
      "When a system at equilibrium is disturbed, it shifts to oppose the change.\n\nApply it three ways:\n- **Concentration:** add a reactant and equilibrium shifts right, toward products.\n- **Pressure:** increase pressure and it shifts toward the side with fewer gas moles.\n- **Temperature:** for an exothermic reaction, raising temperature shifts it left (the endothermic direction).\n\nTemperature is special: it actually changes the value of \$K_c\$, while concentration and pressure changes do not.",
      "**How it's tested:** Usually applied to the Haber or Contact process, predicting the effect of pressure, temperature or concentration on yield (2 to 4 marks).\n\n**Common errors:** Saying a catalyst shifts the position of equilibrium (it only speeds both directions equally), and confusing reaction rate with yield.\n\n**Tricks:** State the direction of shift and link it to gas moles or the sign of ΔH; remember only a temperature change alters the value of Kc."
    ),
    (
      "Why is phenol more acidic than ethanol?",
      "Phenol is more acidic because its conjugate base, the **phenoxide ion**, is stabilised by delocalisation: the negative charge on oxygen spreads into the benzene ring through the \$\\pi\$ system.\n\nIn ethanol's conjugate base (ethoxide) the charge stays localised on the oxygen, and the alkyl group pushes electron density toward it, destabilising it. A more stable conjugate base means \$H^+\$ is released more readily, so phenol has a much lower \$pK_a\$ (~10) than ethanol (~16).",
      "**How it's tested:** Comparing the acidity of phenol, alcohols and carboxylic acids, explained through conjugate-base stability (3 to 4 marks).\n\n**Common errors:** Arguing from the stability of the acid molecule instead of the conjugate base, and forgetting to mention delocalisation into the ring.\n\n**Tricks:** Always reason via the anion's stability, and mention the alkyl group's electron-donating (+I) effect destabilising ethoxide."
    ),
    (
      "Walk me through a buffer calculation",
      "A buffer resists pH change using a weak acid and its conjugate base. Use the **Henderson–Hasselbalch** equation:\n\$\$pH = pK_a + \\log\\frac{[\\text{A}^-]}{[\\text{HA}]}\$\$\n\nExample: 0.10 mol dm⁻³ ethanoic acid (\$pK_a = 4.76\$) with 0.10 mol dm⁻³ sodium ethanoate. Since \$[\\text{A}^-] = [\\text{HA}]\$, the ratio is 1 and \$\\log 1 = 0\$, so \$pH = pK_a = 4.76\$.\n\nWhenever the salt and acid concentrations are equal, pH equals \$pK_a\$ — a handy check.",
      "**How it's tested:** Calculating buffer pH, or its change when a little acid/base is added, with the weak-acid pKa given (often part of an acids–bases question).\n\n**Common errors:** Using starting concentrations without accounting for the neutralisation reaction, and swapping [acid] and [base] in the ratio.\n\n**Tricks:** When [salt] = [acid], pH = pKa; set up a mole table before substituting into Henderson–Hasselbalch."
    ),
  ],
  'Physics': [
    (
      "Explain Newton's second law",
      "The resultant force on an object equals the rate of change of its momentum: \$F = \\frac{\\Delta p}{\\Delta t}\$.\n\nFor constant mass this becomes the familiar \$F = ma\$.\n\nKey exam points:\n- \$F\$ is the **resultant** (net) force, not any single force.\n- Force and acceleration are vectors in the same direction.\n- Resolve forces along your chosen axes before applying it.",
      "**How it's tested:** Resolving forces and applying F = ma on inclines, lifts and connected bodies, or F = Δp/Δt for impulse and variable-mass problems.\n\n**Common errors:** Using weight instead of the resultant force, and forgetting to resolve along the slope.\n\n**Tricks:** Draw a free-body diagram and pick a positive direction first; for impulse, use the area under a force–time graph."
    ),
    (
      "Why does a projectile follow a parabola?",
      "A projectile has two independent motions:\n- **Horizontal:** constant velocity (no force, ignoring air resistance).\n- **Vertical:** constant downward acceleration \$g\$.\n\nHorizontally \$x = u_x t\$, so \$t = x / u_x\$. Vertically \$y = u_y t - \\tfrac{1}{2} g t^2\$. Substituting for \$t\$ gives \$y\$ as a quadratic in \$x\$ — the equation of a **parabola**.\n\nThe two motions share only time; treat them separately.",
      "**How it's tested:** Splitting motion into horizontal and vertical components to find range, maximum height, or time of flight.\n\n**Common errors:** Mixing the two directions (e.g. applying g horizontally), and forgetting the vertical velocity is zero at the top.\n\n**Tricks:** Treat horizontal and vertical separately; time is the only quantity they share."
    ),
    (
      "What is simple harmonic motion?",
      "Simple harmonic motion is oscillation where acceleration is proportional to displacement from equilibrium and always points back toward it:\n\$\$a = -\\omega^2 x\$\$\n\nThe minus sign means it's a restoring acceleration. Consequences:\n- Period \$T = \\frac{2\\pi}{\\omega}\$, independent of amplitude.\n- Velocity is maximum at the centre and zero at the extremes; acceleration is the reverse.\n\nExamples: a mass on a spring, and a pendulum at small angles.",
      "**How it's tested:** Recognising SHM from a = −ω²x, and finding period, maximum speed (vₘₐₓ = ωA), or the energy at a given point.\n\n**Common errors:** Dropping the minus sign / restoring nature, and assuming speed is greatest at the extremes (it is greatest at the centre).\n\n**Tricks:** Period is independent of amplitude; use v = ω√(A² − x²) to link speed and displacement."
    ),
  ],
  'Further Mathematics': [
    (
      "How does de Moivre's theorem work?",
      "De Moivre's theorem says that for any integer \$n\$:\n\$\$(\\cos\\theta + i\\sin\\theta)^n = \\cos n\\theta + i\\sin n\\theta\$\$\n\nIt turns powers and roots of complex numbers into simple operations on the argument.\n\n- **Powers:** raise the modulus to the power \$n\$ and multiply the argument by \$n\$.\n- **Roots:** the \$n\$ distinct \$n\$th roots are equally spaced around a circle, \$\\frac{2\\pi}{n}\$ apart.\n\nIt also derives multiple-angle identities like \$\\cos 3\\theta\$ in terms of \$\\cos\\theta\$.",
      "**How it's tested:** Finding the nth roots of a complex number, proving trigonometric identities, and summing series with complex exponentials.\n\n**Common errors:** Finding only one root instead of all n, and forgetting to add 2kπ to the argument before dividing.\n\n**Tricks:** The n roots are equally spaced 2π/n apart on a circle of radius r^(1/n) — sketch them on an Argand diagram."
    ),
    (
      "What is proof by mathematical induction?",
      "Induction proves a statement \$P(n)\$ holds for all integers from a starting value, in three steps:\n1. **Base case:** show \$P(1)\$ (or the start value) is true.\n2. **Inductive hypothesis:** assume \$P(k)\$ is true for some \$k\$.\n3. **Inductive step:** using that assumption, prove \$P(k+1)\$ follows.\n\nIf the base case holds and each case implies the next, the statement holds for all \$n\$ — like dominoes falling.",
      "**How it's tested:** Proving summation formulae, divisibility results, and properties of recurrence relations or matrices.\n\n**Common errors:** Not actually using the inductive hypothesis in the step, and a vague or missing concluding statement.\n\n**Tricks:** End with the full conclusion: 'since P(1) is true and P(k) implies P(k+1), by induction P(n) is true for all n'."
    ),
    (
      "How do I solve a second-order differential equation?",
      "For a linear equation \$a y'' + b y' + c y = f(x)\$:\n1. Solve the **auxiliary equation** \$a m^2 + b m + c = 0\$ for the complementary function (CF); its form depends on whether the roots are real and distinct, repeated, or complex.\n2. Find a **particular integral** (PI): a trial form matching \$f(x)\$.\n3. The general solution is \$y = \\text{CF} + \\text{PI}\$; then apply any given conditions to fix the constants.",
      "**How it's tested:** Solving homogeneous and non-homogeneous equations, often modelling motion or growth, with conditions given to find the constants.\n\n**Common errors:** Choosing a particular-integral form that clashes with the CF, and applying conditions before combining CF and PI.\n\n**Tricks:** If the trial PI already appears in the CF, multiply it by x; apply the conditions to the full general solution last."
    ),
  ],
  'Mathematics': [
    (
      "Explain the chain rule simply",
      "The chain rule differentiates a **function of a function**. If \$y = f(g(x))\$ then\n\$\$\\frac{dy}{dx} = f'(g(x)) \\cdot g'(x)\$\$\n\nIn words: differentiate the outer function (leaving the inside unchanged), then multiply by the derivative of the inside.\n\nExample: \$y = (3x^2 + 1)^5\$. Outer \$u^5 \\to 5u^4\$; inner \$3x^2+1 \\to 6x\$. So \$\\frac{dy}{dx} = 5(3x^2+1)^4 \\cdot 6x = 30x(3x^2+1)^4\$.",
      "**How it's tested:** Differentiating composite functions, often combined with the product or quotient rule, or inside connected-rates-of-change problems.\n\n**Common errors:** Forgetting to multiply by the derivative of the inside, and stopping after the outer function.\n\n**Tricks:** Identify the 'inside' function first; for a chain within a chain, differentiate outward step by step."
    ),
    (
      "How do I integrate by parts?",
      "Integration by parts reverses the product rule:\n\$\$\\int u \\, dv = uv - \\int v \\, du\$\$\n\nChoose \$u\$ using **LIATE** (Logarithmic, Inverse trig, Algebraic, Trig, Exponential) — pick \$u\$ from whichever appears first.\n\nExample: \$\\int x\\cos x \\, dx\$. Let \$u = x\$ (so \$du = dx\$) and \$dv = \\cos x \\, dx\$ (so \$v = \\sin x\$).\n\$\$\\int x\\cos x \\, dx = x\\sin x - \\int \\sin x \\, dx = x\\sin x + \\cos x + C\$\$",
      "**How it's tested:** Integrating products such as x·eˣ, x·sin x or ln x, sometimes applied twice or as a definite integral.\n\n**Common errors:** Choosing u and dv the wrong way round, and dropping the minus sign before the second integral.\n\n**Tricks:** Use LIATE to pick u; if the integral reappears (e.g. ∫eˣsin x dx), solve for it algebraically."
    ),
    (
      "What is a complex number?",
      "A complex number has a real and an imaginary part: \$z = a + bi\$, where \$i = \\sqrt{-1}\$.\n\n- \$a\$ is the real part, \$b\$ the imaginary part.\n- They let us solve equations like \$x^2 + 1 = 0\$, giving \$x = \\pm i\$.\n- On an **Argand diagram**, \$z\$ is the point \$(a, b)\$, with modulus \$|z| = \\sqrt{a^2 + b^2}\$ and argument measured from the positive real axis.\n\nThey can also be written in polar form \$z = r(\\cos\\theta + i\\sin\\theta)\$.",
      "**How it's tested:** Arithmetic with complex numbers, solving polynomial equations, and modulus–argument (polar) or Argand-diagram work.\n\n**Common errors:** Forgetting that complex roots occur in conjugate pairs, and getting the argument from the wrong quadrant.\n\n**Tricks:** Sketch the Argand diagram to fix the argument's quadrant, and use i² = −1 at every step."
    ),
  ],
  'Economics': [
    (
      "Explain supply and demand simply",
      "**Demand:** as price rises, quantity demanded falls. **Supply:** as price rises, quantity supplied rises.\n\nThe market settles at **equilibrium** — the price where quantity demanded equals quantity supplied.\n- A surplus (excess supply) pushes price down.\n- A shortage (excess demand) pushes price up.\n\nA shift in a whole curve (e.g. higher incomes shifting demand right) moves the equilibrium to a new price and quantity.",
      "**How it's tested:** Using diagrams to distinguish shifts from movements and find the new equilibrium, often evaluating a tax, subsidy or external shock.\n\n**Common errors:** Confusing a shift of the curve with a movement along it, and unlabelled axes or equilibrium points.\n\n**Tricks:** A price change means a movement along; any other determinant means a shift. Always draw and annotate the diagram."
    ),
    (
      "What causes market failure?",
      "Market failure is when a free market allocates resources inefficiently. Main causes:\n- **Externalities:** costs or benefits affecting third parties (e.g. pollution) that the market ignores.\n- **Public goods:** non-rival, non-excludable goods (e.g. street lighting) the market under-provides.\n- **Information failure:** buyers or sellers lack full or symmetric information.\n- **Market dominance:** monopoly power restricting output and raising price.\n\nGovernments respond with taxes, subsidies, regulation, or direct provision.",
      "**How it's tested:** Explaining a source of failure and evaluating a government policy, usually in longer 8 to 25 mark essays.\n\n**Common errors:** Describing the failure without linking it to allocative inefficiency, and one-sided evaluation with no judgement.\n\n**Tricks:** Define the failure, show it on a diagram (e.g. MSC vs MPC for externalities), then weigh the policy and reach a judgement."
    ),
    (
      "What is price elasticity of demand?",
      "Price elasticity of demand measures how responsive quantity demanded is to a price change:\n\$\$PED = \\frac{\\%\\,\\Delta\\,\\text{quantity demanded}}{\\%\\,\\Delta\\,\\text{price}}\$\$\n\n- \$|PED| > 1\$: **elastic** — quantity responds a lot (luxuries, many substitutes).\n- \$|PED| < 1\$: **inelastic** — necessities.\n\nIt's usually negative (price and quantity move oppositely); firms use it to predict how revenue changes when they change price.",
      "**How it's tested:** Calculating PED, classifying demand as elastic or inelastic, and linking it to a firm's total revenue or the incidence of a tax.\n\n**Common errors:** Dropping the sign convention, and confusing PED with income or cross elasticity.\n\n**Tricks:** If demand is inelastic, raising price raises revenue; PED is usually negative, so quote its magnitude."
    ),
  ],
  'Biology': [
    (
      "How does natural selection work?",
      "Natural selection drives evolution in four steps:\n1. **Variation:** individuals differ, due to mutation and sexual reproduction.\n2. **Selection pressure:** more offspring are produced than can survive (competition, predators, environment).\n3. **Differential survival:** individuals with advantageous alleles are likelier to survive and reproduce.\n4. **Inheritance:** those alleles pass on, so their frequency rises over generations.\n\nOver time the population becomes better adapted to its environment.",
      "**How it's tested:** Building a step-by-step account (variation → selection pressure → differential survival → allele-frequency change), usually applied to an example like antibiotic resistance.\n\n**Common errors:** Lamarckian or teleological wording ('organisms try to adapt', 'they need to'), and saying individuals evolve rather than populations.\n\n**Tricks:** Say 'allele frequency in the population changes over generations'; marks come from precise cause-and-effect, not the story."
    ),
    (
      "Explain DNA replication",
      "DNA replication is **semi-conservative** — each new molecule keeps one original strand.\n\nSteps:\n- **DNA helicase** unwinds the double helix and breaks the hydrogen bonds between bases.\n- Each strand acts as a template; free nucleotides pair by complementary base pairing (A–T, C–G).\n- **DNA polymerase** joins the nucleotides into the new strand.\n\nThe result is two identical molecules, each with one old and one new strand.",
      "**How it's tested:** Describing the semi-conservative mechanism and the roles of helicase and DNA polymerase, sometimes interpreting the Meselson–Stahl experiment.\n\n**Common errors:** Confusing replication with transcription, and forgetting the complementary base-pairing rules.\n\n**Tricks:** Name the enzymes and state 'semi-conservative' explicitly; each new molecule keeps one original and one new strand."
    ),
    (
      "Why is osmosis important to cells?",
      "Osmosis is the net movement of water molecules from higher to lower water potential across a partially permeable membrane.\n\nWhy it matters:\n- It controls water entering and leaving cells, affecting volume and turgor.\n- In animal cells, too much inflow causes lysis; too little causes crenation.\n- Plant cells have a wall, so they become turgid without bursting.\n\nWater potential (\$\\Psi\$) combines solute potential and pressure potential.",
      "**How it's tested:** Defining water potential and predicting net water movement in plant or animal cells, often with calculations or mass-change experiment data.\n\n**Common errors:** Saying water moves 'from high to low concentration' (it is water potential), and forgetting Ψ is zero or negative for a solution.\n\n**Tricks:** Water moves down the water-potential gradient (less negative to more negative); Ψ = Ψs + Ψp."
    ),
  ],
  'General Paper': [
    (
      "How do I write a strong GP essay introduction?",
      "A good General Paper introduction does three things quickly:\n- **Engage and contextualise:** open with a sharp, relevant observation, not a dictionary definition.\n- **Define the key terms** so your scope is clear.\n- **Take a clear stand** and signpost the line of argument you will develop.\n\nKeep it to a few sentences. The examiner should know your position and direction before the first body paragraph.",
      "**How it's tested:** Paper 1 is one essay chosen from twelve (50 marks), assessing the quality of your argument, content and language.\n\n**Common errors:** Sitting on the fence with no clear stand, and sweeping claims with no real-world examples.\n\n**Tricks:** Commit to a position early and support it with specific, contemporary examples from different regions and fields."
    ),
    (
      "How do I answer the Application Question in Paper 2?",
      "The Application Question (AQ) asks how far the authors' views apply to you and your society.\n\nFor each view you discuss:\n1. **Identify** the author's specific claim precisely.\n2. **Evaluate** it: does it hold for your society?\n3. **Support** with a concrete local example, then explain the link.\n\nBalance matters — engage with views you both agree and disagree with.",
      "**How it's tested:** Paper 2 ends with the AQ, which rewards evaluation of the passage's ideas against your own society with relevant examples.\n\n**Common errors:** Summarising the author instead of evaluating, and using vague examples with no explanation.\n\n**Tricks:** Anchor each point to a specific Singapore example and explain why the view does or does not apply."
    ),
    (
      "How do I write a good Paper 2 summary?",
      "The summary question tests whether you can identify and rephrase the author's relevant points within a word limit.\n\nMethod:\n- **Select** only the points that answer the summary focus.\n- **Paraphrase** them in your own words — lifting phrases loses marks.\n- **Stay within the word count**, usually flagged where you must start and stop.\n\nIt is about precision and own expression, not your opinion.",
      "**How it's tested:** Paper 2 includes a summary of part of the passage, marked on content points captured and use of own words.\n\n**Common errors:** Lifting whole phrases from the passage, and exceeding the word limit.\n\n**Tricks:** Underline the relevant points first, then rewrite each in your own words; count your words."
    ),
  ],
  'Geography': [
    (
      "What does sustainable development mean?",
      "Sustainable development is meeting present needs without compromising future generations' ability to meet theirs.\n\nIt balances three pillars:\n- **Economic:** growth and livelihoods.\n- **Social:** equity, health and wellbeing.\n- **Environmental:** protecting ecosystems and resources.\n\nThe tension between these — growth versus conservation — is central to most evaluative questions.",
      "**How it's tested:** Data-response questions and extended essays on development, resources and environmental change, requiring real case studies.\n\n**Common errors:** Describing instead of evaluating, and answers with no specific named examples.\n\n**Tricks:** Anchor each argument to a named place or scheme, and weigh the three pillars rather than listing them."
    ),
    (
      "How do I structure a 'to what extent' essay?",
      "A 'to what extent' essay needs a judgement, not a list.\n\n- **Introduction:** define key terms and state your overall position.\n- **Body:** argue both sides — factors that support and factors that limit the claim — each with evidence and a named example.\n- **Conclusion:** reach a clear, justified judgement on the degree, not a simple yes or no.\n\nThe word 'extent' asks you to weigh and rank.",
      "**How it's tested:** Extended essays reward a balanced, evidenced argument that reaches a substantiated judgement.\n\n**Common errors:** One-sided answers, and a conclusion that repeats points without judging the extent.\n\n**Tricks:** Signpost 'however' and 'on balance'; rank the factors and justify which matters most."
    ),
    (
      "How do I tackle a data-response question?",
      "Data-response tests whether you can read and interpret figures, maps or graphs.\n\nApproach:\n- **Describe** the overall trend or pattern first, quoting figures with units.\n- **Spot anomalies** that break the trend.\n- **Explain** using geographical concepts, then link back to the question.\n\nMarks reward precise use of the data, not general knowledge alone.",
      "**How it's tested:** Structured questions built around graphs, maps or tables, marked on accurate data use and geographical explanation.\n\n**Common errors:** Vague description with no quoted figures, and ignoring anomalies.\n\n**Tricks:** Quote values with units, name the trend, then explain it with a concept."
    ),
  ],
  'History': [
    (
      "How do I answer a source-based question?",
      "A source-based question tests how you use and evaluate evidence.\n\nFor each source, weigh its **provenance** — who produced it, when, and **why** (its purpose) — alongside its content. Then:\n- **Cross-reference** sources that agree or disagree.\n- **Use your own knowledge** to judge reliability and usefulness.\n- **Answer the actual question**, grouping sources by argument rather than one by one.\n\nUsefulness depends on the question asked, not just whether a source is biased.",
      "**How it's tested:** A source-based case study requires you to interpret, compare and evaluate a set of sources to reach a judgement.\n\n**Common errors:** Describing sources in turn, and dismissing a source as 'biased' without explaining its value.\n\n**Tricks:** Evaluate using origin, purpose and content; group sources by view and reach a supported overall answer."
    ),
    (
      "What were the main causes of the Cold War?",
      "The Cold War grew from several reinforcing causes:\n- **Ideological conflict:** capitalism and democracy versus communism.\n- **Mutual suspicion:** wartime distrust hardened as the alliance broke down.\n- **Power vacuum:** the collapse of the old order in Europe left the USA and USSR as rival superpowers.\n- **Flashpoints:** disputes over Germany, Eastern Europe and the atomic bomb deepened hostility.\n\nHistorians debate how far each side was responsible — a strong essay weighs this.",
      "**How it's tested:** Argument-led essays asking you to assess causes or responsibility, rewarding a sustained, balanced line of argument.\n\n**Common errors:** Narrating events instead of arguing, and ignoring the historical debate.\n\n**Tricks:** Group causes thematically, weigh their relative importance, and reach a clear judgement."
    ),
    (
      "How do I write an argument-led essay?",
      "An argument-led essay answers the question from the first paragraph, not the last.\n\n- **Introduction:** state your thesis — your overall answer.\n- **Each paragraph:** make a point that supports or qualifies the thesis, back it with specific evidence, then explain its significance.\n- **Conclusion:** confirm your judgement, weighing the factors.\n\nEvery paragraph should serve the argument, not just narrate what happened.",
      "**How it's tested:** Essays are marked on the strength and consistency of your argument, your use of accurate evidence, and your judgement.\n\n**Common errors:** Descriptive 'storytelling' answers, and a thesis that only appears in the conclusion.\n\n**Tricks:** Open with your thesis and link every paragraph back to it with explicit signposting."
    ),
  ],
  'Literature (Eng)': [
    (
      "How do I analyse an unseen poem?",
      "Work from meaning outward to technique.\n1. **Read for sense:** what is the poem about, and what is the speaker's attitude or tone?\n2. **Examine form and structure:** stanza shape, line length, rhythm, rhyme, and any shifts.\n3. **Examine language:** imagery, diction and sound — and crucially the **effect** each creates.\n\nEvery point should connect a technique to its effect on meaning or mood, not just name the device.",
      "**How it's tested:** Passage- or poem-based questions reward close analysis that links form, structure and language to meaning.\n\n**Common errors:** Feature-spotting (naming devices with no effect), and paraphrasing the poem instead of analysing it.\n\n**Tricks:** Use the chain technique then effect then meaning for every point, and quote briefly and precisely."
    ),
    (
      "What should a literature essay introduction do?",
      "A literature introduction should engage directly with the question and the text.\n\n- **Address the key terms** of the question (theme, character, technique).\n- **State your line of argument** — your interpretation, not a plot summary.\n- **Signpost** the aspects you will explore.\n\nAvoid biography and broad context unless it directly serves your reading of the text.",
      "**How it's tested:** Essays on set texts reward a clear interpretive argument sustained with textual evidence.\n\n**Common errors:** Opening with plot summary or author biography, and having no clear thesis.\n\n**Tricks:** Turn the question into a claim and preview your argument; keep the focus on the text."
    ),
    (
      "How do I use quotations effectively?",
      "Quotations should be short, embedded and analysed.\n\n- **Embed** the quote into your own sentence rather than dropping it in alone.\n- **Keep it brief** — a few words is often enough.\n- **Analyse** the specific word choice or device and its effect, then link to your argument.\n\nA single well-analysed word can earn more than a long quotation left unexplained.",
      "**How it's tested:** Marks reward precise textual support and the analysis that follows it, not the amount quoted.\n\n**Common errors:** Long unembedded quotes, and quoting without analysing.\n\n**Tricks:** Embed a short quote, zoom in on one word or image, and explain its effect."
    ),
  ],
  'Computing': [
    (
      "What is Big-O notation?",
      "Big-O notation describes how an algorithm's running time (or memory) grows as the input size \$n\$ grows — the worst-case trend, ignoring constants.\n\nCommon orders, fastest to slowest:\n- \$O(1)\$ constant, \$O(\\log n)\$ logarithmic (e.g. binary search).\n- \$O(n)\$ linear (e.g. linear search), \$O(n \\log n)\$ (good sorts).\n- \$O(n^2)\$ quadratic (e.g. bubble sort), \$O(2^n)\$ exponential.\n\nIt lets you compare algorithms independently of the hardware.",
      "**How it's tested:** Stating and comparing the time complexity of searching and sorting algorithms, and justifying which is more efficient.\n\n**Common errors:** Confusing best and worst case, and keeping constants or lower-order terms (O(2n) should be O(n)).\n\n**Tricks:** Drop constants and lower-order terms; learn the standard complexities of the common algorithms."
    ),
    (
      "What is the difference between a stack and a queue?",
      "Both are linear data structures, but they differ in order of access:\n- **Stack — LIFO** (last in, first out): you **push** to the top and **pop** from the top. Think of a stack of plates.\n- **Queue — FIFO** (first in, first out): you **enqueue** at the back and **dequeue** from the front. Think of a line of people.\n\nStacks suit undo and recursion; queues suit scheduling and buffering.",
      "**How it's tested:** Describing operations, tracing them on given data, and choosing the right structure for a scenario, often with pseudocode.\n\n**Common errors:** Mixing up which end items are added or removed, and forgetting overflow/underflow conditions.\n\n**Tricks:** Remember LIFO vs FIFO, and that both need pointers (top, or front and rear)."
    ),
    (
      "What is database normalisation?",
      "Normalisation organises a relational database to reduce redundancy and avoid update anomalies.\n\n- **1NF:** atomic values, no repeating groups.\n- **2NF:** 1NF plus no partial dependency on part of a composite key.\n- **3NF:** 2NF plus no transitive dependency (non-key attributes depend only on the key).\n\nThe goal is each fact stored once, so updates stay consistent.",
      "**How it's tested:** Normalising a given table to 3NF, identifying anomalies, and explaining keys and dependencies.\n\n**Common errors:** Skipping the partial-dependency check for 2NF, and missing transitive dependencies.\n\n**Tricks:** Work 1NF to 3NF in order; check every non-key attribute depends on the whole key and nothing but the key."
    ),
  ],
  '_generic': [
    (
      "Explain a concept I find tricky",
      "Of course — in the app, tell me the exact topic and I'll break it down in plain English first, with a worked example and the common exam traps to watch for. (This is just a quick demo of how answers look.)",
      ""
    ),
    (
      "How do I structure an essay answer?",
      "A reliable A-Level structure is **PEEL** per paragraph:\n- **Point:** state your argument.\n- **Evidence:** back it with a fact, example, or data.\n- **Explanation:** link the evidence to the point and the question.\n- **Link:** connect back to the overall argument.\n\nOpen with a short intro that defines key terms and signposts your line of argument, and end with a judgement that directly answers the command word.",
      ""
    ),
    (
      "Give me a quick worked example",
      "Here's one — solve \$2x + 3 = 11\$.\n- Subtract 3 from both sides: \$2x = 8\$.\n- Divide by 2: \$x = 4\$.\n\nIn the app, tell me your subject and topic and I'll work through a real exam-style example step by step.",
      ""
    ),
  ],
};
