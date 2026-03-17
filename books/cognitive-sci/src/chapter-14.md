# Chapter 14: Language Development: Nature, Nurture, and the Critical Period

A child is born into a world of noise. The speech she hears is fragmented, overlapping, grammatically imperfect, and riddled with false starts, interruptions, and half-finished thoughts. No one hands her a grammar book. No one explains what a noun is, or that English requires subject-verb agreement, or that questions involve a particular rearrangement of word order. Yet by age four, this child will have mastered the fundamental grammar of her native language. She will produce sentences she has never heard, apply morphological rules to novel words (saying "I goed" instead of "I went," which is wrong but reveals that she has extracted a rule), and understand complex structures involving relative clauses and embedded sentences.

This is one of the most remarkable facts in all of cognitive science. The speed, reliability, and apparent effortlessness of language acquisition stand in sharp contrast to the difficulty adults face learning a second language, and in sharper contrast still to the decades of effort required to build machines that approach human-level language ability. How does a child accomplish this? The answers have been fought over for more than sixty years, and the fight is far from settled.

---

## The Developmental Trajectory

Before we dive into theory, let us lay out what actually happens. The developmental milestones of language acquisition are consistent across languages and cultures to a striking degree, which is itself a fact that demands explanation.

### Babbling (6-10 Months)

Around six months, infants begin producing repetitive consonant-vowel sequences: "bababa," "mamama," "dadada." This babbling is not random. It tends to use the sounds of the ambient language — by about 10 months, the babbling of a French infant sounds different from the babbling of a Japanese infant, even to untrained listeners. Deaf infants exposed to sign language produce "manual babbling" — repetitive hand movements with the rhythmic structure of sign. Babbling, then, is not merely vocal exercise but an exploration of the phonological system the child is acquiring, regardless of whether that system is spoken or signed.

### One-Word Stage (12-18 Months)

Children begin producing recognizable words around their first birthday, though they understand words considerably earlier. The first fifty or so words are typically concrete nouns (ball, dog, mama), social expressions (hi, bye-bye), and a scattering of verbs and adjectives. Production is slow, a new word every few days. Comprehension vocabulary is already much larger than production vocabulary, a gap that persists throughout life.

### Two-Word Stage (18-24 Months)

Somewhere around 18 months, children begin combining words: "more milk," "daddy go," "big dog." These combinations are not random. They respect a rudimentary word order that reflects the grammar of the ambient language. English-learning children put agents before actions and actions before objects, mirroring adult English syntax, even though no one has explicitly taught them this.

### The Grammatical Explosion (24-36 Months)

Between ages two and three, something dramatic happens. Vocabulary growth accelerates sharply (children may learn several new words per day) and grammatical complexity increases rapidly. Children begin using morphological markers (plurals, past tense, possessives), function words (the, is, on), and increasingly complex sentence structures. By age three, most children are producing multi-clause sentences. By age four, the fundamental grammar is in place.

This trajectory is **robust** across languages, though the specific timeline varies depending on the complexity of the morphological system. Children learning languages with richer morphology (like Turkish or Finnish) may take somewhat longer to master the full inflectional system, but the overall sequence is strikingly similar.

---

## The Nativist Proposal: Universal Grammar

The consistency and speed of language acquisition led Noam Chomsky to propose that children are not learning language from scratch. Instead, he argued, they come equipped with an innate language faculty, a set of biological constraints that define the space of possible human grammars. Chomsky called this Universal Grammar (UG).

The argument rests on several pillars.

**The poverty of the stimulus.** The language children hear is messy, incomplete, and degenerate. It does not contain enough information, Chomsky argued, to specify the grammar the child ends up acquiring. Children make errors, but there are systematic errors they never make; they never produce certain logically possible but grammatically impossible structures. This suggests they are constrained by innate knowledge of what human grammars can look like.

**The uniformity of acquisition.** Children acquire language on a similar timetable regardless of intelligence, motivation, or the quantity of input (within a broad range). This suggests a biological maturation process rather than a purely learning-driven one.

**The existence of linguistic universals.** Despite the enormous surface diversity of the world's languages, Chomsky argued that all languages share a common deep structure, a set of principles with parameters that are set by experience. Learning a language, on this view, is not learning a grammar from nothing but setting the switches on an innate system.

Universal Grammar was enormously influential. It provided a clear, testable framework and it focused attention on the logical problem of language acquisition — how children learn so much from so little. Its epistemic status today is **contested**. Many linguists and cognitive scientists continue to work within broadly nativist frameworks, but the specific claims of UG have been substantially revised and the evidence base is less decisive than early proponents suggested.

---

## The Empiricist Counterargument: Statistical Learning

The strongest challenge to the nativist position has come from research demonstrating that infants are far more sophisticated learners than Chomsky assumed. The input is not as impoverished as the poverty-of-the-stimulus argument claimed, and infants extract statistical patterns from that input with impressive efficiency.

Language input, while messy, is not random. It contains rich statistical structure: regularities in the co-occurrence of sounds, words, and phrases. Infants are exquisitely sensitive to this structure from very early in life.

Research has shown that infants can track transitional probabilities between syllables, extract word-like units from continuous speech, learn rudimentary grammatical patterns from distributional information, and generalize abstract rules from limited exposure. The picture that emerges is not one of a passive organism waiting for an innate grammar to mature, but of an active statistical learner extracting structure from the environment at an astonishing rate.

This does not mean that nativism is wrong. Even the strongest empiricists acknowledge that the learning mechanisms themselves must be innately specified; infants are not blank slates. The question is whether the innate endowment is specific to language (as Chomsky claimed) or consists of more general learning mechanisms that happen to be powerful enough to crack the language code. This remains one of the deepest open questions in cognitive science.

---

## Primary Text Spotlight: Saffran, Aslin & Newport (1996)

The study that crystallized the statistical learning approach was published in *Science* in 1996 by Jenny Saffran, Richard Aslin, and Elissa Newport. Its power lies in its simplicity.

### The Problem

How do infants segment continuous speech into words? In natural speech, there are no reliable pauses between words. Somehow, infants must figure out where one word ends and the next begins. This is called the segmentation problem, and it is a necessary first step for building a vocabulary.

### The Design

Saffran and colleagues exposed 8-month-old infants to two minutes of an artificial language, a continuous stream of syllables with no pauses, no intonation cues, no meaning. The stream was constructed from four three-syllable "words" (e.g., "bidaku," "padoti," "golabu," "tupiro") concatenated in random order. The crucial feature was that within a word, the transitional probability between syllables was high (1.0; "bi" was always followed by "da," which was always followed by "ku"). Between words, the transitional probability was low (0.33; the last syllable of one word could be followed by the first syllable of any of the other three words).

After just two minutes of exposure, infants were tested using a head-turn preference procedure. They heard either the words from the language or "part-words" that spanned word boundaries (e.g., "kubido," which crossed from the end of one word to the beginning of another). Infants listened significantly longer to the part-words, a novelty response indicating that they recognized the words as familiar and the part-words as novel.

### Why This Matters

Eight-month-old infants, after two minutes of exposure, extracted word-like units from a continuous stream based solely on statistical regularities. No meaning. No social cues. No explicit instruction. Just transitional probabilities.

This result has been replicated extensively and extended in numerous directions. Infants can track more complex statistical relationships, generalize abstract patterns (like "ABA" versus "ABB" sequences), and perform statistical learning across multiple sensory modalities. The finding is **robust**.

### What It Does Not Show

Statistical learning is a powerful mechanism, but Saffran and colleagues were careful not to overclaim. Their study shows that infants can use transitional probabilities to segment an artificial language under laboratory conditions. It does not show that this is how infants segment natural language, which contains many additional cues (prosody, phonotactic constraints, familiar words). It does not show that statistical learning is sufficient for grammar acquisition, which involves structures far more complex than sequences of syllables. And it does not resolve the nativist-empiricist debate; nativists can argue that the statistical learning mechanism itself is part of the innate endowment.

What the study does show, powerfully, is that the infant mind is not waiting passively for innate knowledge to unfold. It is actively computing over its input from very early in life.

---

## Critical Periods and Sensitive Periods

One of the strongest pieces of evidence for a biological component to language acquisition comes from timing. Language is much easier to learn early in life than later. But the nature and boundaries of this effect are more complex than the popular version suggests.

The concept of a critical period comes from biology: Konrad Lorenz's goslings, who would imprint on whatever they saw during a narrow window after hatching. Applied to language, the strong version of the critical period hypothesis claims that there is a biologically determined window, roughly birth to puberty, during which language acquisition is possible, and after which it becomes impossible.

Most researchers now prefer the term **sensitive period**, which allows for a more graded decline rather than a sharp cutoff. The evidence suggests that different aspects of language have different sensitive periods. Phonological learning (acquiring native-like pronunciation) seems to have the earliest and narrowest window; by late childhood, it becomes very difficult to acquire a new phonological system without an accent. Grammatical learning has a somewhat later and wider window. Vocabulary learning continues efficiently throughout life.

The strongest evidence for sensitive periods comes from studies of second-language learners who immigrated at different ages, and from cases of severely deprived children.

### The Case of Genie

In 1970, a 13-year-old girl known as Genie was discovered in Los Angeles. She had been confined to a small room by her abusive father for nearly her entire life, strapped to a chair or crib, with almost no human interaction and virtually no exposure to language. When rescued, she had essentially no language.

Genie's case offered a tragic natural experiment on the critical period hypothesis. She received intensive language therapy and did learn a substantial vocabulary. But she never acquired normal grammar. Her speech remained telegraphic ("Applesauce buy store"), lacking the morphological and syntactic complexity that even three-year-olds typically command.

The case is often cited as evidence for the critical period hypothesis, and in a general sense it is consistent with it. But we must be honest about its limitations. Genie suffered severe deprivation across every dimension (nutritional, social, emotional, cognitive), not just linguistic deprivation. Her case cannot tell us whether her language difficulties resulted from missing a critical period for language specifically, or from the catastrophic effects of global deprivation on brain development. A sample size of one, under conditions of extreme abuse, does not allow clean causal inference.

More informative, if less dramatic, evidence comes from studies of deaf individuals who were exposed to sign language at different ages. Those who learned sign from birth perform like native speakers. Those who first encountered sign language at age five or later show persistent grammatical differences, even after decades of use. This pattern, early exposure producing qualitatively different mastery, is consistent with a sensitive period for grammar, and its status is **robust**.

---

## Bilingualism: Benefits and Myths

Roughly half the world's population is bilingual or multilingual, making monolingualism the exception rather than the rule in human experience. Yet much of the research on language acquisition has focused on monolingual children, and popular beliefs about bilingualism are riddled with misconceptions.

### What the Evidence Shows

Bilingual children reach language milestones on roughly the same timetable as monolinguals. They may have a smaller vocabulary in each individual language at early ages, but their total vocabulary across both languages is typically comparable to or larger than that of monolinguals. They do not experience language "confusion" in any harmful sense. Code-switching (mixing languages within a conversation) is not a sign of deficiency but a sophisticated communicative strategy governed by its own systematic rules.

### The Bilingual Advantage: A Cautionary Tale

For roughly two decades, a prominent line of research claimed that bilingualism confers a cognitive advantage, specifically enhanced executive function and attentional control. The proposed mechanism was that constantly managing two languages exercises the cognitive control system, producing benefits that transfer to non-linguistic tasks. Several studies reported that bilingual children and adults outperformed monolinguals on tasks requiring inhibition and task-switching.

This claim was widely publicized and enthusiastically received. However, more recent large-scale studies and meta-analyses have failed to find consistent evidence for the bilingual advantage. The original studies tended to be small, and the effect may have been inflated by publication bias and by confounds between bilingualism and other variables (socioeconomic status, immigration experience, cultural factors).

The current status of the bilingual cognitive advantage is **fragile**. There may be real but small effects in specific populations or specific tasks, but the broad claim of a general executive function advantage is not well supported. This does not diminish the many real benefits of bilingualism (cultural, social, communicative, and economic), but it should make us cautious about overselling cognitive benefits on the basis of uncertain evidence.

---

## What This Gets Right / What's Still Open

**What we understand well:** The developmental trajectory of language acquisition is well-documented and consistent across languages. Infants are powerful statistical learners. Sensitive periods for language exist, with different timing for different components. Bilingual acquisition follows a normal trajectory.

**What remains open:** The nativist-empiricist debate is not resolved. We do not know whether the innate endowment for language is language-specific (as Chomsky argued) or domain-general (as statistical learning researchers suggest). The precise mechanisms of grammatical acquisition, how children move from tracking transitional probabilities to producing recursive syntactic structures, remain unclear. The neural changes underlying sensitive periods are not well understood. And the bilingual advantage debate has not reached a satisfying conclusion.

---

## Real-World Application

### Early Childhood Education

The research on language development has clear implications for early childhood education. The quantity and quality of language input in the first few years of life matter enormously. The famous "30-million-word gap" study by Hart and Risley (1995) claimed that children from higher-income families heard 30 million more words by age four than children from lower-income families. While the specific numbers have been debated and the study's methodology criticized, the broader point (that early language exposure varies dramatically and correlates with later outcomes) is supported by subsequent research. Programs that increase conversational interaction (not just passive exposure to speech) in early childhood show positive effects on vocabulary development.

### Second-Language Instruction

The sensitive period research has direct implications for language education policy. If grammatical acquisition is substantially easier before puberty, there is a strong argument for beginning second-language instruction in elementary school rather than high school. Many countries have adopted this approach. However, the research also shows that adults are not incapable of learning a second language. They can learn vocabulary and grammar effectively, even if achieving native-like pronunciation becomes much harder.

### "Baby Genius" Products

The statistical learning research has been co-opted by companies selling "educational" DVDs, apps, and programs for infants and toddlers. The logic seems sound: if babies are statistical learners, why not give them more data to learn from? But the evidence for these products is poor. A landmark study by DeLoache and colleagues (2010) found that infants who watched a popular "baby vocabulary" DVD did not learn the target words any better than infants who had no exposure to the DVD. What predicted vocabulary growth was live social interaction — parents talking with their children.

This illustrates a recurring theme in developmental science: the mechanisms that evolution built for learning are tuned to natural social interaction, not to passive media consumption. Statistical learning is powerful, but it operates most effectively in the context of a responsive social environment. Screens are not a substitute for conversation.

---

## Checkpoint

By this point, you should be able to affirm the following:

- You can describe the major stages of language development (babbling, one-word, two-word, grammatical explosion) and their approximate timing.
- You understand Chomsky's Universal Grammar proposal and the poverty-of-the-stimulus argument that motivates it.
- You can explain what statistical learning is and what Saffran, Aslin, and Newport's 1996 study demonstrated.
- You understand the difference between a critical period and a sensitive period, and why the latter term is now preferred.
- You can discuss what Genie's case does and does not tell us about language acquisition.
- You know the current state of evidence regarding the bilingual cognitive advantage (fragile) and can distinguish it from the genuine benefits of bilingualism.
- You can articulate why "baby genius" products lack empirical support despite being inspired by real science.
- You understand that the nativist-empiricist debate remains open and can state at least one strong argument on each side.
