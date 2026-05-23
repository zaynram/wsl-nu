use std/util "path add"
const IPEX_LLM_OLLAMA_HOME: path = $nu.home-dir | path join .ipex-llm-ollama

module ipex-llm-ollama {
    def "sycl list" []: nothing -> oneof<string, any> {
        ^($nu.home-dir | path join .ipex-llm-ollama ls-sycl-device)
    }
    def "start ollama" []: nothing -> nothing {
        cd ($nu.home-dir | path join .ipex-llm-ollama)
        bash start-ollama.sh
    }
}

if ($IPEX_LLM_OLLAMA_HOME | path exists) {
    path add $IPEX_LLM_OLLAMA_HOME
    overlay use ipex-llm-ollama
}
