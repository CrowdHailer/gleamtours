import { Ok, Error } from "./gleam.mjs";

export async function fetchFact() {
    try {
        let response = await fetch("https://catfact.ninja/fact")
        let {fact} = await response.json()
        return new Ok(fact)
    } catch (error) {
        return new Error(`${error}`)
    }
}