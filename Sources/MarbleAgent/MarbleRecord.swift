import GraniteAgents

/// Marble's place in Granite's roster: an app that links this package finds the `marble` agent with
/// `GraniteRoster.discovered()`, with nothing listed by hand.
@used @section("__DATA_CONST,__granite")
let marbleRecord: GraniteRoster.Record = { GraniteRoster.record(MarbleAgent.self) }
