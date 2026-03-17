# Chapter 6: Motor Cognition and Action: The Other Half of the Loop

You reach for your coffee without thinking. Your hand shapes itself to the mug's handle before you've consciously registered the mug's position. You catch a ball tossed to you across a room, and your hand arrives at the interception point before you could possibly have "decided" where that point would be. A pianist's fingers fly across keys at twelve notes per second, far too fast for each movement to be individually commanded.

These are not reflexes. They are skilled, context-sensitive, goal-directed actions. They raise a question that turns out to be important for cognitive science: how does the brain plan actions it hasn't consciously decided to take?

For most of the twentieth century, the study of cognition treated action as an afterthought, the "output" side of a system whose interesting work happened between input and output. Perception was input, thought was processing, and movement was just the boring part where you told your muscles what to do. This chapter argues that this picture is backwards. Action is not cognition's servant. It is cognition's partner, and in many cases, its origin.

---

## Motor Planning and Programming

Let us start with a distinction that matters more than it first appears: the difference between motor planning and motor programming.

Motor planning is the high-level specification of what you want to do. Pick up the mug. Catch the ball. Walk to the door. These plans are abstract. They specify goals and rough strategies but not the precise pattern of muscle activations needed to achieve them.

Motor programming is the translation of that plan into specific commands: which muscles contract, in what order, with how much force, for how long. This is where the computational demands become staggering. Your arm has seven degrees of freedom at the joints alone. To reach for a mug, the brain must coordinate timing and force across dozens of muscles, compensate for the current position and velocity of the arm, account for the weight of whatever you're already holding, and do all of this in roughly 200 to 400 milliseconds.

The key insight is that these two levels are genuinely separable. Evidence comes from studies of brain-damaged patients. Some individuals can describe what action they want to perform (intact planning) but cannot execute it smoothly (impaired programming), a condition called apraxia. Others can execute well-practiced movements fluidly but struggle to plan novel sequences. The brain appears to handle the "what" and the "how" of action in partially distinct systems, with planning relying more on parietal and prefrontal cortex and programming depending more on motor cortex, cerebellum, and basal ganglia.

---

## Internal Models: Predicting What You Haven't Done Yet

When you reach for your coffee, there is a delay of roughly 100 to 200 milliseconds between when your brain sends a motor command and when sensory feedback about the movement's result arrives back. At normal reaching speeds, your hand moves several centimeters during that delay. If you relied solely on sensory feedback to guide your movements, you would always be correcting for where your hand was a fifth of a second ago. You would overshoot, oscillate, and spill your coffee everywhere.

You do not spill your coffee everywhere (usually). This means the brain must be doing something more clever than waiting for feedback. The dominant theory is that it maintains **internal models**, neural simulations of the body and its interactions with the world.

Two types of internal model do most of the explanatory work.

**Forward models** predict the sensory consequences of a motor command before those consequences actually arrive. When you send a command to move your arm, a forward model simultaneously predicts what that movement will feel like, look like, and where it will end up. This prediction serves as a stand-in for actual feedback during the delay, allowing smooth, rapid corrections.

Forward models also explain why you cannot tickle yourself. When you move your own fingers across your skin, the forward model predicts the resulting sensation and cancels it out. The sensation is not surprising, so it does not tickle. When someone else touches you, no prediction is available, and the sensation registers fully. Patients with certain kinds of schizophrenia, whose forward models may be impaired, sometimes can tickle themselves. It is a small but telling clinical observation.

**Inverse models** work in the other direction. Given a desired outcome (hand arrives at mug), the inverse model computes the motor commands needed to achieve it. This is computationally harder than it sounds, because the same endpoint can be reached by many different combinations of joint angles and muscle forces, the "degrees of freedom problem" first identified by the Russian physiologist Nikolai Bernstein in the 1930s-40s (though his work became widely known in the West only in the 1960s).

Together, forward and inverse models form a loop: the inverse model generates commands, the forward model predicts their consequences, and discrepancies between prediction and actual feedback drive learning and correction. This architecture shows up across many domains of cognitive science, and we will encounter versions of it again when we discuss language processing and social cognition.

---

## Fitts's Law: A Robust Quantitative Regularity

Cognitive science does not produce many laws in the physics sense, precise quantitative relationships that hold across conditions. Fitts's Law is one of the rare exceptions, and it has held up well since Paul Fitts proposed it in 1954.

The law describes the speed-accuracy tradeoff in aimed movements. In its simplest form:

**Movement time = a + b x log2(2D / W)**

where D is the distance to the target, W is the width of the target, a and b are empirical constants, and the logarithmic term is called the "index of difficulty."

In plain language: it takes longer to hit smaller targets and targets that are farther away, and the relationship is logarithmic. Double the distance, and movement time increases by a constant amount. Halve the target width, same constant increase.

What makes Fitts's Law notable is its generality. It holds for movements of the hand, the foot, the head. It holds for movements made with a stylus on a tablet, a mouse on a screen, or a finger on a phone. It holds across age groups and, with adjusted constants, across populations with motor impairments. It holds under water. It is one of the most replicated findings in all of experimental psychology.

The law tells us something important about motor control: the brain appears to optimize a tradeoff between speed and accuracy using the same strategy regardless of which effector (body part or tool) is doing the moving. This suggests that motor planning operates at an abstract level, specifying goals in terms of spatial accuracy, not muscle commands.

---

## The Ideomotor Principle: Actions as Their Effects

In the late nineteenth century, William James proposed what he called the ideomotor principle: the idea that actions are mentally represented not by the muscle commands that produce them but by the sensory effects they achieve. You do not think "contract biceps, extend triceps, flex wrist" when you reach for a light switch. You think "light goes on." The action is coded in terms of its intended effect.

This idea was largely ignored for a century, then revived in the 1990s by the psychologist Bernhard Hommel and colleagues under the label "Theory of Event Coding." The evidence is now substantial. When people plan an action, they are faster to detect stimuli that resemble the action's anticipated effects. Watching someone else perform an action activates the same effect representations that would be activated if you performed the action yourself. The mental representation of an action and the mental representation of its perceptual consequences appear to share neural territory.

This has profound implications. If actions are represented by their effects, then the boundary between perception and action is not where we thought it was. Perceiving an event and planning to cause that same event use overlapping neural codes. This "common coding" hypothesis connects motor cognition to perception, attention, and even social understanding in ways we are still working out.

---

## Mirror Neurons: What They Do and Do Not Tell Us

In the early 1990s, Giacomo Rizzolatti and colleagues at the University of Parma discovered neurons in the macaque premotor cortex that fired both when a monkey performed an action (like grasping a peanut) and when it observed another monkey or a human performing the same action. They called these "mirror neurons."

The discovery was important. It provided direct neural evidence for the kind of action-perception overlap that the ideomotor principle predicts. In macaques, the finding is well-established and has been replicated many times.

What happened next is a cautionary tale about scientific enthusiasm. Mirror neurons were proposed as the neural basis of empathy, language, imitation, theory of mind, and even consciousness. Vilayanur Ramachandran called them "the driving force behind the great leap forward in human evolution." Popular science writers called them "empathy neurons."

The reality is more modest, and more interesting. In humans, we have good evidence for mirror-like activity — brain regions that respond both during action execution and action observation. But we do not have single-neuron recordings of the kind available in macaques (with a few recent exceptions from patients with implanted electrodes). The broader claims about empathy and language remain speculative. People with damage to the putative human mirror system do not necessarily lose empathy. The link to language evolution is plausible but unproven.

A lesson worth remembering as we move through this book: a real discovery can be simultaneously important and oversold. Mirror neurons tell us something real about how the brain links perception and action. They do not tell us everything about what makes us human.

---

## Affordances Revisited

In Chapter 4, we encountered James Gibson's concept of affordances, the possibilities for action that an environment offers to an organism. A chair affords sitting. A mug handle affords grasping. A doorway affords walking through.

With motor cognition as background, affordances take on a richer meaning. Perceiving an affordance is not a passive registration of an object's properties. It is the activation of a motor plan. Neuroimaging studies consistently show that viewing graspable objects activates motor and premotor cortex, even when no action is required or intended. You see a mug, and your brain partially prepares to grasp it.

This is not a quirk. It is a feature. An organism that perceives the world in terms of what it can do with that world is better prepared to act quickly when action is needed. Perception and action are not sequential stages in a pipeline. They are concurrent, interleaved processes that continuously shape each other.

---

## Primary Text Spotlight: Wolpert, Ghahramani & Jordan (1995)

Daniel Wolpert, Zoubin Ghahramani, and Michael Jordan published "An Internal Model for Sensorimotor Integration" in *Science* in 1995. The paper is technically precise, well-designed, and has shaped how we think about motor control ever since.

The authors' core argument is that the brain maintains a forward model that predicts the sensory consequences of motor commands, and that this prediction is integrated with actual sensory feedback using a process analogous to a Kalman filter, an optimal statistical method for combining noisy predictions with noisy observations.

The experiment was deceptively simple. Participants held their right hand stationary while an external motor moved their left forearm. At various points during the movement, the motor stopped, and participants were asked to indicate where their left hand was using their right hand. The key manipulation was the delay between when the movement stopped and when participants made their judgment.

With no delay, participants were accurate. With increasing delay, their estimates drifted in the direction the hand had been moving, as if the brain's forward model continued predicting the hand's trajectory even after the hand had stopped. The drift was systematic and consistent with a model that combines predicted position (from the forward model) with actual sensory information (from proprioception), weighting the prediction more heavily as actual feedback becomes stale.

This is a strong result for several reasons. First, it demonstrates that the brain does not simply track limb position through sensory feedback alone; it actively predicts. Second, it shows that the prediction and the feedback are combined in a statistically principled way. Third, it provides a computational framework (the Kalman filter) that makes quantitative predictions about how estimates should change over time, and those predictions match the data.

The Wolpert, Ghahramani, and Jordan framework has become foundational. Subsequent work has extended internal model theory to explain motor learning, adaptation to novel tools, and the sense of agency, the feeling that you are the one causing your actions. When the forward model's prediction matches sensory feedback, you feel in control. When it does not, you feel that something external is acting on you.

---

## Case Study: Phantom Limbs and the Rubber Hand

When the brain's body model conflicts with sensory reality, the results are dramatic and revealing.

**Phantom limb pain** occurs in roughly 60 to 80 percent of amputees. After losing a limb, patients often continue to feel the limb's presence, and frequently experience pain in a limb that no longer exists. The pain is not imagined. It is generated by a brain that maintains an internal model of a body that no longer matches reality.

V.S. Ramachandran proposed that phantom pain arises in part because the brain's forward model sends motor commands to the missing limb, predicts sensory feedback, and receives none. The mismatch between prediction and feedback generates an error signal that the brain interprets as pain. His mirror box therapy, in which patients view the reflection of their intact hand in a mirror to create the visual illusion of a restored limb, can reduce phantom pain by providing the visual feedback the forward model expects. It demonstrates that the brain's body model can be updated through sensory input, even when that input is illusory.

**The rubber hand illusion**, which we first encountered in Chapter 4's discussion of cross-modal perception, makes a complementary point about motor cognition specifically. Recall that when an experimenter synchronously strokes a visible rubber hand and a participant's hidden real hand, participants begin to experience the rubber hand as their own. The motor significance is this: body ownership is not hardwired but a dynamic inference, continuously updated based on multisensory correlation. The brain assigns ownership to whatever body part best fits the available evidence. This is the internal model framework applied to the body itself: the brain maintains a model of its own body, and that model can be fooled.

---

## What This Gets Right / What's Still Open

**Well established:** Internal models, both forward and inverse, are among the most successful theoretical constructs in motor neuroscience. The evidence spans behavioral experiments, neuroimaging, computational modeling, and clinical populations. Fitts's Law remains one of the most robust quantitative relationships in psychology. The basic phenomenology of phantom limbs and body ownership illusions is solidly documented.

**Still debated:** The relationship between motor cognition and higher thought is active territory. Some researchers argue that abstract thinking is grounded in motor simulation, that when you understand a sentence about kicking a ball, you partially simulate the kicking action. Others argue that motor activation during language processing is a side effect, not a cause, of comprehension. The degree to which perception and action share representations (the "common coding" idea) is supported by considerable evidence but not universally accepted.

**Emerging:** The role of the cerebellum in cognition beyond motor control is a growing area. Once considered a purely motor structure, the cerebellum is now implicated in timing, prediction, language, and social cognition. If the cerebellum implements forward models, and forward models are useful beyond motor control, then the cerebellum's cognitive role makes architectural sense. But the details are far from settled.

---

## Real-World Application

### Fitts's Law in Interface Design

Fitts's Law is not an academic curiosity. It is a foundational principle of human-computer interaction. The reason buttons on your phone are a certain minimum size, the reason menus at the edge of a screen are easier to hit than menus floating in the middle, the reason drag-and-drop targets expand when you approach them: all of these design choices follow from Fitts's Law.

The law predicts that infinite-width targets (like a screen edge) have an effective index of difficulty of zero in one dimension, making them trivially easy to hit. This is why macOS places the menu bar at the top edge of the screen rather than at the top of the application window. It is a small decision with a measurable impact on task performance.

### Motor Cognition in Stroke Rehabilitation

Understanding internal models has changed how we approach rehabilitation after stroke. Traditional rehabilitation focused on having patients practice movements repeatedly. Modern approaches additionally target the internal model itself.

Constraint-induced movement therapy forces patients to use their affected limb by restraining the unaffected one, driving the brain to update its internal model of what the affected limb can do. Mental practice (imagining movements without performing them) activates motor cortex and can improve function, consistent with the idea that motor imagery relies on the same forward models as actual execution.

Robot-assisted rehabilitation can provide the kind of controlled, predictable sensory feedback that helps recalibrate internal models after neural damage. The theory does not only describe motor control; it generates specific, testable strategies for restoring it.

---

## Checkpoint

Before moving on, you should be able to affirm the following:

- You can explain the difference between motor planning and motor programming and why the distinction matters.
- You understand what forward and inverse models are, and can describe at least one experiment that supports the forward model account.
- You can state Fitts's Law in plain language and explain why it is significant for both cognitive science and practical design.
- You understand the ideomotor principle, that actions are represented by their anticipated effects, and can see how this blurs the line between perception and action.
- You can give an honest assessment of what mirror neurons do and do not demonstrate.
- You can explain how phantom limb pain and the rubber hand illusion reveal the brain's internal body model.
- You can articulate why motor cognition is not just "the output side" of the mind but a central part of how we perceive, think, and understand.
