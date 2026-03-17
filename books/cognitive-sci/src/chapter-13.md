# Chapter 13: Language Processing: From Sound to Meaning

Right now, as you read this sentence, you are performing one of the most computationally demanding feats in all of cognition. You are converting a stream of visual marks into sounds, words, meanings, and intentions — and you are doing it so quickly that the effort is invisible. In spoken conversation, the challenge is even greater. Normal speech arrives at roughly 150 words per minute, about three words per second. Each word must be identified from a mental dictionary of tens of thousands of entries, assigned a grammatical role, integrated into a sentence-level meaning, and connected to the broader context of the conversation. You do all of this in real time, with almost no conscious effort, while simultaneously planning what you are going to say next.

How does this work? How can a biological system parse a continuous, noisy, ambiguous signal into structured meaning at that speed? The answer requires us to examine language at multiple levels, from the raw acoustic signal up through the pragmatic interpretation of what a speaker actually meant. It also requires us to confront a question that has shaped cognitive science since its founding: how much of this ability is built into the architecture of the human mind, and how much is learned from experience?

---

## The Levels of Language

Linguists traditionally carve language into several levels of analysis, each with its own regularities and its own processing demands.

**Phonology** deals with the sound system of a language: the inventory of speech sounds (phonemes) and the rules governing how they combine. English has roughly 44 phonemes, depending on dialect. Mandarin has a different set, as does Swahili. The point is that every language selects a small subset from the space of possible human speech sounds and organizes them into a system.

**Morphology** concerns the internal structure of words. The word "unhappiness" is not an arbitrary unit; it is built from the root "happy," the prefix "un-," and the suffix "-ness," each contributing predictable meaning. Some languages, like Turkish and Finnish, have extraordinarily rich morphological systems where a single word can encode information that English would require an entire clause to express.

**Syntax** is the system of rules governing how words combine into phrases and sentences. "The dog bit the man" and "The man bit the dog" use identical words but mean very different things, entirely because of their structural arrangement.

**Semantics** addresses meaning: what words and sentences refer to, how meanings compose, and how ambiguity gets resolved.

**Pragmatics** deals with meaning in context. When someone says "Can you pass the salt?" they are not asking about your physical abilities. Pragmatic processing lets you recognize this as a request, not a question.

These levels are not processed in a strict sequence. As we will see, evidence strongly suggests that information from multiple levels interacts during comprehension, often in parallel. But the distinctions remain useful for understanding the different computational problems the language system must solve.

---

## Speech Perception: Hearing What Isn't There

Consider the physical speech signal. When you listen to someone talk, you hear discrete words separated by pauses. But if you look at a spectrogram, a visual representation of the acoustic signal, you will find something surprising: there are often no reliable pauses between words. The signal is largely continuous. The gaps you perceive are constructed by your language processing system.

This is not the only way speech perception goes beyond the signal. Two notable demonstrations involve categorical perception and the McGurk effect.

### Categorical Perception

Speech sounds vary along continuous acoustic dimensions. The difference between "ba" and "pa," for instance, corresponds to a continuous variable called voice onset time, the delay between when the lips open and when the vocal cords begin vibrating. You can synthesize sounds that vary smoothly along this dimension. But listeners do not hear a smooth continuum. Instead, they hear a sharp boundary: sounds on one side are clearly "ba," sounds on the other side are clearly "pa," and the transition region is narrow. Within each category, large acoustic differences are nearly invisible to perception. Across the category boundary, small acoustic differences produce a dramatic perceptual shift.

This categorical perception is **robust**; it has been demonstrated across many languages and laboratories. It suggests that the speech perception system is not passively recording acoustic input but actively sorting it into linguistically relevant categories.

### The McGurk Effect Revisited

The McGurk effect, which we encountered in Chapter 4, is worth revisiting in the context of language. Recall that watching someone mouth "ga" while hearing "ba" produces the percept "da," a fusion of visual and auditory signals. For speech perception specifically, the implication is important: language processing is multimodal from the start. Visual information about articulatory gestures is not supplementary but integrated into the core percept. This will matter when we discuss reading, which routes language through the visual system entirely.

---

## Lexical Access: Finding Words in the Mental Lexicon

Once the speech signal has been parsed into something like a sequence of phonemes, the next challenge is word recognition. You need to match the incoming sound pattern to an entry in your mental lexicon, your internal dictionary of word forms, their meanings, and their grammatical properties. Estimates of the size of this lexicon vary, but educated adults typically know between 20,000 and 60,000 word families.

The speed of lexical access is remarkable. Experimental evidence suggests that a spoken word is typically recognized within about 200 to 300 milliseconds of its onset, often before the speaker has finished saying it. You are not waiting for the entire word to arrive before beginning to identify it.

The dominant model of spoken word recognition for decades has been the cohort model, originally proposed by William Marslen-Wilson. The idea is that the initial sounds of a word activate a "cohort" of all words that begin with those sounds. As more of the word is heard, candidates that no longer match are eliminated, until a single candidate remains — the recognition point. If you hear "eleph-", the word "elephant" is likely the only remaining candidate, and recognition can occur before the final syllable.

For visual word recognition (reading), the picture is somewhat different, and we will turn to that shortly.

---

## Sentence Processing: Gardens, Paths, and Arguments

Recognizing individual words is necessary but not sufficient for understanding language. Words must be assembled into syntactic structures that determine who did what to whom. This process turns out to be far from simple.

### Garden-Path Sentences

Consider: "The horse raced past the barn fell." Most readers stumble on this sentence. You likely interpreted "raced" as the main verb (the horse was racing past the barn) and then "fell" arrives with no grammatical role to play. The sentence is actually grammatical: it means the horse that was raced past the barn (by someone) fell. "Raced past the barn" is a reduced relative clause modifying "horse." Your parser committed to the wrong structure early and had to backtrack.

These garden-path sentences have been a primary tool for studying how the parser makes its initial structural commitments. The evidence suggests that the parser does not wait until the end of a sentence to start building structure. It commits incrementally, sometimes incorrectly, and must occasionally revise.

### The Interactivity Debate

A major theoretical question is whether the parser's initial commitments are based solely on syntactic information, or whether semantic and contextual information can influence the earliest stages of parsing. The garden-path theory associated with Lyn Frazier proposed that initial parsing is driven purely by structural principles; the parser prefers simpler structures. Constraint-based models, by contrast, argue that multiple sources of information (syntax, semantics, word frequency, context) all contribute to parsing from the very beginning.

This debate is **contested**. Eye-tracking studies have provided evidence for both positions, depending on the specific materials and conditions. The emerging consensus, if there is one, is that the system is highly interactive but that structural information carries particular weight in the earliest moments of processing.

---

## Reading: A Recent Invention the Brain Was Not Designed For

Reading is arguably the most remarkable cognitive skill humans have invented. Writing systems are only about 5,000 years old, far too recent for natural selection to have shaped dedicated neural circuits for reading. Yet skilled readers process written text with extraordinary speed and accuracy. How does the brain repurpose existing machinery for a task it never evolved to perform?

### The Dual-Route Model

The most influential model of single-word reading is the dual-route cascaded model. It proposes two pathways from print to pronunciation.

The **lexical route** treats familiar words as whole units. When you see "yacht," you do not sound it out letter by letter. You recognize it as a stored pattern and retrieve its pronunciation directly from your mental lexicon. This route handles irregular words (words whose pronunciation does not follow standard spelling-to-sound rules) and is sensitive to word frequency: common words are recognized faster.

The **sublexical route** converts letters (graphemes) to sounds (phonemes) using learned spelling-to-sound rules. This is the route you rely on when encountering a novel word or a pronounceable nonword like "blint." You apply rules to generate a pronunciation even though you have never seen the letter string before.

Evidence for two routes comes from patterns of reading impairment. Some patients with brain damage can read irregular words like "yacht" but struggle with nonwords, suggesting damage to the sublexical route. Others can read nonwords but regularize irregular words, pronouncing "yacht" to rhyme with "matched," suggesting damage to the lexical route. This double dissociation is among the strongest pieces of evidence for the dual-route architecture, and its status is **robust**.

### Orthographic Processing and the Visual Word Form Area

Reading requires the visual system to develop specialized processing for letter strings. Neuroimaging studies have identified a region in the left fusiform gyrus, sometimes called the visual word form area (VWFA), that responds preferentially to written words and letter-like stimuli. This region appears to be recycled from circuitry that originally processed other fine-grained visual distinctions, consistent with Stanislas Dehaene's "neuronal recycling" hypothesis. The VWFA is not a genetically specified reading module; it is a region whose function is shaped by literacy experience. Illiterate adults do not show the same pattern of activation.

### Eye Movements During Reading

Reading does not involve smoothly scanning text from left to right. Instead, your eyes make rapid jumps called saccades, landing on fixation points for roughly 200 to 250 milliseconds before jumping to the next position. These fixation patterns are not random; they reveal the real-time processing demands of reading.

Content words (nouns, verbs) receive longer fixations than function words (the, of, is). Predictable words are fixated more briefly or skipped entirely. When a reader encounters a difficult or ambiguous word, fixation durations increase, and regressive eye movements (looking back) occur. Eye-tracking during reading has become one of the most powerful tools in psycholinguistics because it provides a millisecond-by-millisecond record of processing difficulty.

### Dyslexia: What It Reveals About Reading Architecture

Developmental dyslexia affects an estimated 5 to 10 percent of the population, depending on the diagnostic criteria and the language studied. It is a specific difficulty with reading that is not explained by low intelligence, poor vision, or inadequate instruction. Dyslexia matters as a practical concern and also as a window into the architecture of reading.

The most well-supported account is the phonological deficit hypothesis: most dyslexic readers have difficulty with the mental representation and manipulation of speech sounds, which impairs the sublexical grapheme-to-phoneme route. This is **robust** as a description of the most common subtype, though dyslexia is almost certainly heterogeneous, with some individuals showing primarily visual or attentional difficulties.

What dyslexia is not: it is not "seeing letters backwards," despite persistent popular belief. It is not a sign of low intelligence; many dyslexic individuals are highly capable in domains that do not depend on fluent reading. And it is not a simple product of insufficient practice, though practice certainly helps.

Dyslexia underscores that reading is not a single ability but a complex system with multiple components, each of which can break down somewhat independently.

---

## Computational Models of Language

The history of computational approaches to language mirrors a broader shift in cognitive science from rule-based to statistical to neural network models.

Early approaches, inspired by Chomsky's formal grammar framework, attempted to process language using explicit symbolic rules. These systems could parse well-formed sentences according to a grammar, but they struggled with the ambiguity, noise, and variability of real language.

Statistical models, beginning in the 1980s and 1990s, took a different approach: instead of writing rules, they estimated probabilities from large bodies of text. These models could handle ambiguity by choosing the most probable interpretation given the available evidence. They did not "understand" language in any deep sense, but they performed surprisingly well on practical tasks.

Modern large language models (LLMs) like GPT-4 and its successors represent a further evolution. Trained on enormous text corpora, they produce highly fluent language and can perform tasks (summarization, translation, question-answering) that seemed to require understanding. What do they tell us about human language processing?

The honest answer is: less than the hype suggests, but more than skeptics claim. LLMs demonstrate that statistical patterns in language carry far more information than early linguists believed. They show that you can get very far without anything resembling a traditional grammar. But they process language in ways that differ from humans in important respects: they require vastly more data, they lack grounding in physical experience, and they fail on tasks that require understanding of causality, intention, or physical possibility. They are extraordinary engineering achievements and suggestive existence proofs, but they are not models of human language processing in any direct sense. This is **contested** territory, with researchers disagreeing sharply about what LLMs reveal about the nature of language.

---

## Primary Text Spotlight: Chomsky's Review of Skinner's *Verbal Behavior* (1959)

In 1957, the behaviorist B.F. Skinner published *Verbal Behavior*, an ambitious attempt to explain language entirely in terms of stimulus, response, and reinforcement, the standard tools of behaviorist psychology. In 1959, a young linguist named Noam Chomsky published a review that is widely credited with launching the cognitive revolution in the study of language.

Chomsky's central argument was devastating in its simplicity: the behaviorist framework is inadequate for explaining the core properties of human language. His key points included:

**The poverty of the stimulus.** Children produce and understand sentences they have never heard before. Language use is a generative system that creates novel combinations from finite means, not a repertoire of practiced responses. Reinforcement cannot explain this creativity because there is no mechanism by which a child could be reinforced for producing a sentence that has never existed before.

**The abstraction of grammatical knowledge.** Speakers know things about their language (for instance, that "John is eager to please" and "John is easy to please" have different deep structures despite their surface similarity) that cannot be explained by associating words with stimuli. This knowledge is abstract, structural, and systematic.

**The universality of acquisition.** Children across wildly different cultures and languages acquire grammar on a strikingly similar timetable, despite dramatic variation in the quantity and quality of input. This suggests that something about the capacity for language is biologically endowed rather than entirely learned from environmental contingencies.

Chomsky did more than criticize Skinner. He proposed an alternative vision: that humans possess an innate language faculty, a biological endowment that constrains the space of possible grammars and makes language acquisition possible. This proposal, later formalized as Universal Grammar, would dominate linguistics for decades and remains influential, if increasingly contested.

The review is important not because Chomsky was right about everything (he was not, as later chapters will discuss) but because it established that language requires a different kind of explanation than stimulus-response association. It opened the door to treating language as a cognitive system with its own internal structure, subject to its own principles, an idea that is foundational to modern cognitive science.

---

## Case Study: Broca's Area, Wernicke's Area, and the Neural Geography of Language

In 1861, the French physician Paul Broca examined a patient who could understand speech but could produce only a single syllable: "tan." After the patient's death, Broca identified damage to the left inferior frontal gyrus. He concluded that this region was the seat of speech production.

In 1874, the German neurologist Carl Wernicke described patients with damage to the left posterior superior temporal gyrus who could produce fluent speech but whose output was largely meaningless; they could not comprehend language. Wernicke proposed that this region was critical for language comprehension.

The classical model that emerged was tidy: Broca's area handles production, Wernicke's area handles comprehension, and the arcuate fasciculus connecting them enables repetition. Damage to Broca's area produces non-fluent aphasia (effortful, telegraphic speech with relatively preserved comprehension). Damage to Wernicke's area produces fluent aphasia (flowing but meaningless speech with impaired comprehension).

This model is still taught and still useful as a first approximation. But neuroimaging has complicated it considerably. Brain imaging studies of healthy participants performing language tasks show activation in a distributed network that extends well beyond the classical areas. Broca's area is involved in comprehension as well as production, particularly when syntactic processing is demanding. Wernicke's area contributes to production as well as comprehension. And the right hemisphere, long considered linguistically silent, contributes to prosody, metaphor, and discourse-level processing.

The current understanding is that language is supported by a large-scale network, primarily left-lateralized but not exclusively so, rather than by two neatly circumscribed modules. The lesion cases that founded the field remain invaluable, but the simple localizationist story they seemed to tell was an oversimplification. This progression from clean simplicity to messy complexity is characteristic of cognitive neuroscience.

---

## What This Gets Right / What's Still Open

**What we understand well:** The basic architecture of reading (dual-route model) has strong support. Categorical perception of speech is well-established. The incremental, predictive nature of sentence processing is well-documented. Lesion studies provide reliable information about the necessity of particular regions for particular functions.

**What remains open:** The interactivity debate in parsing is not fully settled. The degree to which LLMs capture human-like linguistic knowledge is hotly debated. The relationship between language processing and general cognitive resources (attention, working memory) is unclear. How the brain supports the compositionality of meaning, building sentence meaning from word meanings, remains one of the deepest unsolved problems in cognitive science.

---

## Real-World Application

### Machine Translation

Modern neural machine translation systems have improved dramatically, to the point where casual translation between major language pairs is often serviceable. But systematic failures reveal the boundaries of current approaches. Translation systems struggle with pragmatics (irony, implicature), with culturally embedded metaphors, and with languages that encode information very differently from English. Research on human language processing, particularly on how context, world knowledge, and communicative intent contribute to comprehension, continues to inform the development of more capable translation systems.

### Reading Intervention

Research on reading architecture has direct implications for education. The phonological deficit account of dyslexia has led to evidence-based interventions emphasizing phonological awareness training — helping children hear and manipulate the sound structure of language. These interventions are most effective when delivered early, consistent with the idea that the sublexical route is foundational for reading development. Whole-language approaches that minimize explicit phonics instruction have been largely abandoned in favor of structured literacy programs grounded in the dual-route model.

### Second-Language Instruction

Understanding how lexical access, syntactic parsing, and phonological processing work in a first language has informed approaches to second-language teaching. For instance, research on categorical perception explains why adult learners of a new language struggle to hear distinctions that are not present in their native phonological system, because the perceptual categories are already established. Targeted training can help, but the difficulty is real and has a clear cognitive basis.

---

## Checkpoint

By this point, you should be able to affirm the following:

- You can name the five levels of linguistic analysis (phonology, morphology, syntax, semantics, pragmatics) and explain what each addresses.
- You understand what categorical perception is and why it matters for speech perception.
- You can explain the dual-route model of reading and the evidence from acquired dyslexia that supports it.
- You know what a garden-path sentence is and what it reveals about incremental parsing.
- You understand the basic distinction between Broca's and Wernicke's aphasia, and why the classical model has been complicated by neuroimaging.
- You can articulate Chomsky's core argument against Skinner and why it mattered for cognitive science.
- You can explain what developmental dyslexia is, what it is not, and what the phonological deficit hypothesis proposes.
- You can state at least one thing LLMs tell us about language and one thing they do not.
