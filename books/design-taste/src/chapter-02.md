# Typography — The Whole Game

*If you get type right, you can get away with almost anything else. If you get type wrong, nothing else will save you.*

---

## Opening

Ninety-five percent of what you see on any web page is text. Text in headings, text in paragraphs, text in buttons, text in navigation, text in captions, text in error messages. You can strip away the images, remove the icons, eliminate the illustrations, and what remains is still recognizable as an interface. Strip away the text and you have nothing.

This makes typography the highest-leverage design skill. Small improvements in how you set type ripple through everything. Large mistakes in typography poison interfaces that are otherwise well-considered. A product with mediocre illustration but excellent typography will feel professional. A product with excellent illustration but mediocre typography will feel amateur.

Typography is also the skill that AI handles worst. Generative tools can suggest type pairings from their training data, but they can't feel the difference between a pairing that harmonizes and one that *sings*. They set type at default sizes with default spacing because defaults are what they've learned. The nuance — the spacing adjustment that makes a headline breathe, the weight shift that creates tension between head and body, the optical corrections that account for how letters actually look rather than how they measure — that nuance is where your value lives.

This chapter is comprehensive. It covers anatomy, classification, setting, and pairing. But it's not a reference manual. It's a taste-development journey. By the end, you should be able to look at any interface and evaluate its typographic choices with precision — and you should be able to make better choices yourself.

---

## Why Typography Comes First

When a designer talks about "visual hierarchy," they're mostly talking about typography. The heading establishes importance. The subhead provides context. The body delivers content. The caption adds detail. The label identifies. Each typographic element has a role, and the relationships between them create the structure users navigate.

This hierarchy isn't decorative. It's functional. When a user lands on a page, their eye needs to find a starting point. That starting point is almost always the largest, boldest text — the headline. From there, they scan for context — usually a subhead or introductory paragraph. If the hierarchy is clear, this happens effortlessly. If the hierarchy is muddled — if the headline isn't meaningfully larger than the subhead, if the body text doesn't clearly subordinate to the heading — the user has to work to understand the page's structure.

Typography also carries emotional weight. A page set in geometric sans-serifs like Circular or Futura feels different from the same content set in an old-style serif like Garamond. The geometry reads as modern, precise, perhaps clinical. The serif reads as warm, established, literary. Neither is better. Both are choices, and the choice should serve the product's intent.

The danger for engineers is treating type as an implementation detail. You pick a system font because it's available. You use whatever sizes the framework suggests. You don't think about the emotional register because nobody told you to. But users feel the typography even if they can't name what they're feeling. The cold, generic feel of a product set in Roboto at framework defaults tells users nothing about the product's personality. It tells them, subconsciously, that nobody cared.

---

## Anatomy of a Letterform

Before you can make typographic choices, you need vocabulary. These aren't definitions to memorize — they're perceptual tools. Each anatomical feature affects how type looks at different sizes, how it pairs with other typefaces, and what personality it projects.

The **baseline** is the invisible line that letters sit on. Most letters rest on the baseline; some, like the descender of a lowercase "g," drop below it. When you align text, you're aligning baselines. When you set line-height, you're measuring from baseline to baseline.

The **x-height** is the height of lowercase letters like "x" that have no ascenders or descenders. This is the single most important property for screen readability. A typeface with a tall x-height — where the lowercase letters are large relative to the capitals — is more legible at small sizes because more of the letter is in the "reading zone." Source Sans Pro has a tall x-height and remains crisp at 14px. Garamond has a relatively short x-height and starts to lose definition below 16px.

The **cap height** is the height of capital letters. The relationship between cap height and x-height affects how "open" or "compact" a typeface feels. A large x-height relative to cap height creates a democratic feeling — capitals don't tower over lowercase. A small x-height relative to cap height creates a more classical, hierarchical feeling.

**Ascenders** are the parts of lowercase letters that rise above the x-height — the top of a "b," "d," "h," "l." **Descenders** are the parts that fall below the baseline — the tail of a "g," "p," "y," "q." Long ascenders and descenders give a typeface elegance but require more line-height to prevent collisions between lines.

**Stroke contrast** describes the variation between thick and thin parts of a letter. A typeface with high stroke contrast — like Didot, where the vertical strokes are thick and the horizontal strokes are hairlines — is dramatic and elegant but harder to read at small sizes, where the thin strokes can disappear. A typeface with low stroke contrast — like Helvetica, where all strokes are nearly uniform — is more neutral but also more monotonous.

**Serifs** are the small finishing strokes at the ends of letters in serif typefaces. **Bracketed serifs** curve smoothly into the main stroke (like in Garamond). **Unbracketed serifs** meet the stroke at a sharp angle (like in Bodoni). **Slab serifs** are thick, blocky terminals (like in Rockwell). The style of serif — or its absence — fundamentally changes the typeface's personality.

**Terminals** are the endings of strokes in letters without serifs, or in the curved parts of serif letters. A **ball terminal** ends in a circular shape (like in Bodoni). A **flat terminal** ends in a horizontal cut. An **angled terminal** ends in a diagonal. These details seem minor but they accumulate into a typeface's overall feeling — ball terminals feel classic and finished; flat terminals feel modern and neutral.

When you look at a typeface, you're perceiving all these features simultaneously, even if you can't name them. Training yourself to see them explicitly — to notice that this typeface has a tall x-height and low stroke contrast and flat terminals — gives you the vocabulary to articulate why one typeface feels right and another doesn't.

---

## The Families

Typefaces cluster into families based on historical origin and structural features. Understanding these families helps you make informed choices and articulate why certain pairings work.

### Old-Style Serifs

Garamond, Bembo, Jenson, Palatino. These typefaces descend from Renaissance models. They have moderate stroke contrast, bracketed serifs, and an axis of stress that tilts slightly left — an artifact of how pen-and-ink calligraphy was held.

The emotional register is warm, literary, trustworthy. Old-style serifs say "we've been around, we're established, you can trust us." They work beautifully for long-form reading — books, articles, editorial content. They can feel dated in tech contexts, though this is changing as more tech brands seek to differentiate from geometric sans-serif sameness.

**Taste trap:** Using old-style serifs at sizes where their refinement becomes invisible. Bembo at 14px on screen loses most of its character. If you're going to use an old-style serif, make sure it's at a size where the details read.

### Transitional Serifs

Baskerville, Georgia, Times New Roman, Plantin. These emerged in the 18th century as a bridge between old-style and modern serifs. They have more stroke contrast than old-style, more vertical stress, and sharper, less bracketed serifs.

The emotional register is professional, balanced, authoritative. Transitional serifs say "we're serious, we're credible, we're not playing around." They're the default for academic papers, newspapers, and anywhere trustworthiness matters. Georgia was designed specifically for screens and remains one of the most readable serif typefaces at small sizes.

**Taste trap:** Defaulting to Times New Roman because it's available. TNR has become so ubiquitous — particularly in contexts like Word documents and legal briefs — that using it broadcasts "I didn't make a choice." If you want a transitional serif, pick one with more character: Baskerville, Georgia, or something less default.

### Modern/Didone Serifs

Didot, Bodoni, Walbaum. These arrived in the late 18th and early 19th centuries, pushing stroke contrast to extremes. The thick strokes are thick; the thin strokes are hairlines. The serifs are unbracketed, meeting the stroke at sharp right angles.

The emotional register is dramatic, elegant, editorial, high-fashion. Vogue has used Didot for over a century. Bodoni announces *importance*. These typefaces demand attention.

**Taste trap:** Using Didone serifs at small sizes. Those hairline strokes disappear. Didot at 14px on a screen is not elegant — it's unreadable. Reserve Didones for display use: headlines, logos, editorial callouts. At body sizes, they fail.

### Slab Serifs

Rockwell, Clarendon, Sentinel, Archer. These have thick, blocky serifs with minimal or no bracketing. They emerged in the 19th century for advertising, where they needed to command attention.

The emotional register varies by the specific face. Rockwell is industrial, bold, no-nonsense. Archer (with its ball terminals and subtle curves) is friendly, approachable, warm. Sentinel is sturdy, reliable, Americana. The category is broad; the personality depends on the face.

**Taste trap:** Assuming all slab serifs are interchangeable. The difference between Rockwell and Archer is enormous. One says "industrial factory"; the other says "friendly bakery." Know your slabs.

### Humanist Sans-Serifs

Gill Sans, Frutiger, Source Sans Pro, Open Sans, Whitney. These sans-serifs retain some calligraphic influence — strokes that vary in width, apertures that open generously, forms that feel organic rather than constructed.

The emotional register is warm, readable, approachable. Humanist sans-serifs say "we're modern, but we're also human." They're excellent for interface text because they combine sans-serif clarity with readability that approaches serif typefaces. Frutiger was designed for airport signage — it needed to be readable at a distance, in motion, at a glance.

**Taste trap:** Using humanist sans-serifs when you want pure neutrality. Their warmth is a feature, but it's also a constraint. If you need maximum neutrality — a design system that should fade into the background — a grotesque might serve better.

### Grotesque/Neo-Grotesque Sans-Serifs

Helvetica, Univers, Aktiv Grotesk, Inter, Suisse Int'l. These are the "neutral" sans-serifs, with minimal stroke contrast, uniform shapes, and a goal of being as anonymous as possible.

The emotional register is systematic, neutral, modernist. Helvetica is everywhere because it tries to be nothing. It's the typeface of corporations, governments, transit systems — anywhere the message matters more than the messenger.

**Taste trap:** Using Helvetica or Inter because they're safe. Safe is fine. But safe also means undifferentiated. Every tech product using Inter looks like every other tech product using Inter. If you choose a grotesque, know that you're choosing to blend in. Sometimes that's right. Sometimes it's a missed opportunity.

### Geometric Sans-Serifs

Futura, Avenir, Circular, Proxima Nova, Gotham. These are constructed from geometric shapes — circles, squares, lines. The "o" is often a near-perfect circle. The "a" is often single-story.

The emotional register is precise, contemporary, tech-forward. Geometric sans-serifs have dominated startup branding for a decade. Circular (or its cheaper lookalikes) is the default logo typeface for half the companies in Y Combinator.

**Taste trap:** The geometric sans-serif danger zone is severe. Because everyone uses them, they've become a marker of "startup trying to look like a startup." Using Circular in 2026 is like using Helvetica Neue in 2010 — it was once modern, and now it's a cliché. If you use a geometric sans-serif, you need a compelling reason beyond "it looks like what tech companies use."

---

## Setting Type That Breathes

Choosing a typeface is only the beginning. How you *set* that typeface — the sizes, spacing, and proportions — is where craft lives.

### Line-Height

Line-height (or leading, from the days of metal type) is the vertical space between lines of text. Too tight and lines collide, making text hard to parse. Too loose and the eye loses the connection between lines, making it hard to track from the end of one line to the beginning of the next.

For body text, the standard range is 1.4 to 1.6 times the font size. A 16px body text usually works with 24px to 26px line-height. The exact value depends on the typeface's x-height and the measure (line length) — typefaces with tall x-heights can tolerate tighter line-height, and longer lines need more line-height to help the eye track back.

Headlines need tighter line-height than body text. A multi-line headline at 48px with 1.5 line-height feels disconnected — too much air between the lines. Headlines typically work at 1.1 to 1.3 times the font size. The goal is a unified block, not separate lines.

**The error:** Engineers often set uniform line-height across all sizes. A 1.5 line-height that works for 16px body text produces 72px line-height at 48px headline size — far too loose. Adjust line-height per size class.

### Measure (Line Length)

The **measure** is the length of a line of text, usually expressed in characters. For comfortable reading, the ideal measure is 45 to 75 characters per line. Too short (under 40 characters) and the eye is constantly jumping to the next line, creating a choppy reading experience. Too long (over 80 characters) and the eye struggles to track back to the start of the next line, often landing on the wrong line.

On screens, this usually means body text needs a `max-width`. Don't let paragraphs span the full viewport on a wide monitor. A common implementation: `max-width: 65ch` on the container, where `ch` is the width of the "0" character in the current font — a good proxy for average character width.

**The error:** Full-width paragraphs on desktop. They look fine at narrow viewports, then become unreadable at wide viewports. Always constrain the measure.

### Letter-Spacing (Tracking)

**Tracking** is uniform adjustment of spacing between all letters in a text. There are only a few situations where it's appropriate.

**All-caps text benefits from positive tracking.** Capitals were designed to sit next to lowercase letters, which have ascenders and descenders that create vertical rhythm. All-caps text loses that rhythm and can feel cramped. Add 0.05em to 0.1em of tracking to give all-caps room to breathe.

**Very large display text sometimes benefits from negative tracking.** At headline sizes — 48px, 64px, larger — the spacing that looks right at body size can feel loose. Subtle negative tracking (-0.02em) can create a more cohesive headline block.

**Never track lowercase body text.** The default spacing was designed by the type designer for that exact purpose. Adding tracking to body text disrupts the carefully calibrated rhythm of the typeface. If the body text feels too tight or too loose, you have the wrong typeface, not a tracking problem.

### Size and Scale

Type sizes should follow a deliberate scale, not arbitrary values. The standard approach is to use a modular scale: pick a ratio and multiply the base size repeatedly to generate your scale.

Common ratios:
- **Minor Second (1.067):** Very tight scale, small differences between sizes
- **Major Third (1.25):** Moderate scale, clear but not dramatic hierarchy
- **Perfect Fourth (1.333):** Strong hierarchy, good for interfaces with clear levels
- **Golden Ratio (1.618):** Dramatic differences, useful for editorial and marketing

For a 16px base with a 1.25 ratio: 16, 20, 25, 31, 39, 49. Each step is a meaningful increment. A heading at 25px is clearly larger than body at 16px, but not dramatically so. A hero heading at 49px commands attention.

The mistake is using arbitrary sizes: 14, 16, 18, 24, 32. These create inconsistent visual intervals. The jump from 16 to 18 is barely perceptible; the jump from 24 to 32 is large. A modular scale creates consistent perceptual steps.

### Typographic Color

Here's a concept that separates amateur type setting from professional: **typographic color**. This has nothing to do with actual color. It refers to the overall grayness of a text block when you squint at it.

Well-set type has even color — a uniform gray texture across the block. You achieve this through correct line-height, appropriate tracking (which should be zero for body text), proper justification (or ragged-right alignment, which is usually safer), and a typeface with even stroke weights.

Poor typographic color shows up as light or dark spots — rivers of white space running vertically through justified text, tight clumps where certain letter combinations create dense clusters, loose areas where wide letters sit next to each other.

Train yourself to evaluate typographic color by squinting at text blocks until they blur. The blur reveals the overall texture. If the texture is uneven — dark patches, light patches, rivers — the typesetting needs work.

---

## Pairing Typefaces

The question designers hear most often about typography is "what typefaces go together?" The answer is more systematic than most people realize.

### The Axis of Contrast Model

A good pairing differs on at least one axis but shares at least one axis of similarity. The axes include:

**Structure:** Serif vs. sans-serif is the most obvious structural difference, but there are others — slab serif vs. bracketed serif, geometric sans vs. humanist sans, high stroke contrast vs. low stroke contrast.

**Weight:** Light vs. bold, condensed vs. extended. A light, airy display face can pair with a sturdy, workmanlike body face.

**Era:** A 16th-century old-style serif can pair with a 20th-century geometric sans because the era contrast creates productive tension.

**Formality:** A casual, handwritten-influenced face can pair with a strict, constructed face.

**Width:** A condensed typeface can pair with a regular-width typeface.

The principle: contrast creates interest, similarity creates coherence. If two typefaces are too similar — two grotesque sans-serifs, say, or two transitional serifs — they'll feel redundant rather than complementary. If they're too different — with no shared characteristics at all — they'll clash rather than converse.

### Specific Pairing Strategies

**Superfamily pairs:** Many typeface families include both serif and sans-serif versions designed to work together. Source Serif and Source Sans. Merriweather and Merriweather Sans. IBM Plex Serif and IBM Plex Sans. These are safe pairs — designed by the same designer with matching proportions and details. They don't create tension, but they don't clash either.

**Same designer, different faces:** Typefaces by the same designer often share subtle characteristics that make them pair well. Gill Sans and Joanna were both designed by Eric Gill and share certain stroke endings and proportions.

**Complementary eras:** A contemporary geometric sans paired with a classic old-style serif creates productive tension between modern and traditional. Futura and Garamond. Circular and Caslon. The contrast says "we know the traditions and we're building on them."

**Role-based pairing:** Don't choose two faces that try to do the same job. If your headline face is dramatic and attention-grabbing, your body face should be quiet and readable. If your headline face is restrained, your body face can be slightly more characterful. The pair should feel like a conversation between complementary voices, not two people talking over each other.

### The One-Typeface Rule

Often the best pairing is no pairing at all. A single typeface family used at different weights, sizes, and possibly italics can create all the hierarchy you need. This approach is harder to get wrong and produces automatic coherence.

Helvetica at regular weight for body, medium weight for subheads, bold weight for headings, light weight for large display. That's four visual levels from one typeface family. The hierarchy comes from size and weight, not from competing letterforms.

This doesn't mean single-typeface design is always right. But if you're unsure about pairing, start with one typeface. It's a stronger default than a mediocre pair.

---

## The Display vs. Body Distinction

Not every typeface works at every size. Some are designed for headlines; some are designed for sustained reading. Using the wrong typeface for the role produces predictable failures.

**Display typefaces** are optimized for large sizes. They often have high stroke contrast, refined details, tighter default spacing, and characteristics that would make them illegible or awkward at small sizes. Didot, Playfair Display, Abril Fatface — these typefaces sing at 48px and collapse at 14px. The hairline strokes disappear. The refined details become noise.

**Text typefaces** are optimized for body copy. They have lower stroke contrast (so thin strokes remain visible at small sizes), generous x-heights (so the readable portion of the letter is maximized), and open apertures (so counters don't fill in). Charter, Source Serif, Georgia — these typefaces are built for 14px to 18px paragraphs and sustained reading. At headline sizes, they often look plain or even dull. They weren't designed to command attention; they were designed to become invisible while you read.

The mistake is using a display typeface for body text (unreadable) or a text typeface where you need visual impact (underwhelming). Match the typeface to the role.

### Variable Fonts: The Modern Solution

**Variable fonts** have moved from novelty to standard practice. A single variable font file contains an entire design space — every weight from thin to black, every width from condensed to extended, and often optical sizing adjustments — all interpolated on demand.

The practical benefits are significant:

**Optical sizing.** The most important axis for taste. A variable font with an `opsz` axis automatically adjusts letterforms based on size. At large sizes (headlines), the font increases stroke contrast, tightens spacing, and refines details. At small sizes (body text), it reduces contrast, opens counters, and increases x-height slightly. This is how metal type worked — each size was a separate cut, optimized for that size. Variable fonts bring this back, automatically.

**Weight interpolation.** Instead of choosing from fixed weights (400, 500, 600, 700), you can set any value (450, 580, 650). This enables precise tuning: maybe your subheads need something between medium and semibold. With variable fonts, you specify `font-weight: 550` and get exactly that.

**Width variation.** Some variable fonts include a width axis, enabling condensed-to-extended interpolation. Useful for responsive typography: slightly condense headings on narrow viewports rather than breaking to multiple lines.

**Performance.** One variable font file often weighs less than multiple static font files covering the same design space. Loading Inter as a variable font is smaller than loading Inter Regular, Medium, Semibold, and Bold as separate files.

**Implementation.** CSS supports variable fonts directly:

```css
/* Optical sizing (automatic adjustment by size) */
font-optical-sizing: auto;

/* Fine-tuned weight */
font-variation-settings: 'wght' 550;

/* Or using standard properties */
font-weight: 550;
font-stretch: 95%;
```

The taste advantage: variable fonts enable precision that fixed fonts don't. You're not choosing from a menu of 6 weights — you're dialing in exactly the weight that creates the hierarchy you want. This granular control is where typographic refinement lives.

When choosing typefaces for a new project, check if a variable version exists. For the workhorse typefaces (Inter, Source Sans, Roboto), variable versions are standard. Use them.

---

## Taste Interlude: Harmonious vs. Alive

This is the distinction that separates good typography from exceptional typography. Both are achievable. Most people stop at good.

A **harmonious** type pairing is two typefaces that don't clash. They share enough characteristics that they feel related. They don't compete for attention. They're comfortable together. Most competent type pairings achieve harmony.

An **alive** type pairing is two typefaces whose differences create productive tension — like a conversation between two people who share values but have different personalities. The sans-serif heading is precise and assertive; the serif body text is warm and flowing. They're not the same, and the *not-same-ness* creates energy. The page feels animated, not static.

The difference is subtle and difficult to articulate, which is why it's the province of taste rather than rules. But here's a way to perceive it: look at the pairing and ask whether it creates *energy* or merely *order*. Harmonious pairings create order — everything fits, nothing clashes, the system works. Alive pairings create energy — the slight friction between the typefaces generates visual interest that keeps the page from feeling flat.

One path to alive pairings: let the body typeface be more characterful than the headline typeface. Most designers do the opposite — dramatic headline, neutral body. But a restrained headline (Aktiv Grotesk, say) with a body typeface that has more voice (Source Serif, with its slightly idiosyncratic details) can create an aliveness that the reverse doesn't. The body text carries the personality; the headlines stay out of the way.

Another path: find typefaces that share a philosophical kinship but diverge in execution. Baskerville and Futura are from different centuries with different structural logic, but both aspire to a kind of rational perfection — Baskerville's 18th-century enlightenment ideals, Futura's 20th-century geometric modernism. They share an intent while differing in form, and that shared intent creates coherence while the formal differences create energy.

This is what training your eye means. You're developing the ability to perceive these distinctions — to feel when a pairing merely works versus when it *sings*.

---

## AI Integration

AI tools provide a novel way to develop typographic taste: generation and comparison.

Try this exercise: Use an AI tool to generate 10 type specimens for a fictional product. Give it the same content — the same headline, subhead, body paragraph, and caption — and let it make typographic choices for each specimen. It will select typefaces, set sizes, establish hierarchy, choose spacing.

Now look at what it produced.

You'll notice patterns. The same handful of typefaces appear repeatedly — whatever was most common in the training data. The sizing follows predictable ratios. The spacing is neither tight nor loose but somewhere safe in the middle. The choices are competent and completely interchangeable. Nothing distinguishes specimen three from specimen seven. They're all fine. None are memorable.

Now set your own specimens. Make different choices. Choose a typeface the AI didn't suggest. Set spacing that feels right for *this* content rather than generically correct. Create a hierarchy that serves the specific meaning of these specific words.

Compare your specimens to the AI's. Name three specific things your specimens do that the AI's don't. Maybe you used a typeface with more character. Maybe you set tighter line-height to create a more intimate feel. Maybe you let the heading run longer than "best practice" because this particular heading needed room to breathe.

Those three things you named? That's the gap. That's your taste, articulated. Every time you can name what you did that a machine wouldn't, you've identified a dimension of your value.

---

## Projects

### Project 1: Type Specimen Sheets

Choose three typefaces you've never used before. For each, create a single-page HTML specimen showing: one headline, one subhead, one body paragraph, one pull quote, one caption, and one data label.

**Constraints:**
- No images, no icons, no illustrations
- No color beyond black, white, and one accent (which you must use sparingly)
- Each specimen must be a complete HTML file with hand-written CSS — no frameworks, no component libraries
- The three typefaces must come from different families (you can't do three geometric sans-serifs)

**Process:**
- After completing your three specimens, generate 10 AI specimens for the same content
- Compare your specimens to the AI's
- Write a 200-word analysis of what your specimens do that the AI's don't

**Taste check:**
- Do your specimens communicate something specific about each typeface's personality? Or do they feel generic?
- Look at your size scale, your spacing, your line-height. Did you make those choices deliberately, or did you use defaults?
- Show your specimens to someone who doesn't know anything about type. Ask them to describe the "feeling" of each. Do their descriptions match what you intended?

### Project 2: Typography-Only Redesign

Take a real website — yours or someone else's — and redesign *only* the typography. Same layout. Same content. Same colors. Same spacing. Change only the typefaces, type sizes, type weights, and type-related properties (line-height, letter-spacing).

**Constraints:**
- You must produce three versions:
  - **Editorial:** The typography of a magazine or high-end publication
  - **Technical:** The typography of a developer tool or documentation
  - **Warm:** The typography of a friendly consumer product
- Each version must use different typefaces and different type hierarchies
- You cannot change the layout, colors, imagery, or spacing between elements

**Deliverable:**
- Three live HTML/CSS versions of the site
- A written brief (300-500 words) explaining the typographic choices in each version: which typefaces, why those typefaces, how you established hierarchy, what feeling you were aiming for

**Taste check:**
- Do the three versions feel genuinely different, or are they minor variations?
- Could someone who saw only one version correctly identify which direction it was (editorial, technical, warm)?
- Which version do you believe in? Ship that one. (If it's your own site, this isn't hypothetical — actually ship it.)

### Project 3: Type Crime Audit

Pick three startup marketing sites — real sites, for real companies. For each, conduct a complete typography audit.

**For each site, document:**
- What typefaces are in use and where
- The type scale (list every size you can find)
- Whether hierarchy is clear or confused
- Specific instances where typography is working well (with explanation of why)
- Specific instances where typography is failing (with explanation of why and proposed fix)

**Constraints:**
- At least one of the three sites must be a site you think is well-designed overall — you're looking for typographic issues even in otherwise good work
- Your proposed fixes must be specific: "Change the subhead from 18px to 24px" not "Make the hierarchy clearer"
- You must mock up at least one fix per site (a before/after showing your proposed change)

**Deliverable:**
- Three audit documents (one per site), each approximately 400-600 words
- Three before/after mockups showing one fix per site
- Post at least one audit publicly (on your blog, Twitter, wherever). This is about practice and also about building a public body of work that demonstrates taste.

**Taste check:**
- Were you able to find issues even in well-designed sites? (If not, you're not looking hard enough.)
- Are your proposed fixes actually improvements? Show them to someone else and ask.
- Did writing the audit change how you see these sites? What did you notice that you wouldn't have noticed before this chapter?
