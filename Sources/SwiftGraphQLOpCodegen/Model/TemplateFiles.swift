import Foundation
import PathKit

struct TemplateFiles {
    let protocolTemplate: File
    let operationTemplate: File

    init() throws {
        let templatePaths = Bundle.module.paths(
            forResourcesOfType: "stencil",
            inDirectory: "Templates"
        )

        var operationTemplate: File?
        var protocolTemplate: File?

        for path in templatePaths {
            let path = Path(path)
            let readFile = { File(path: path, content: try path.read()) }

            switch path.lastComponent {
            case "Operation.stencil":
                operationTemplate = try readFile()
            case "GraphQLOperation.stencil":
                protocolTemplate = try readFile()
            default:
                // TODO: Warning log
                print("Warning: Unhandled bundled template \(path.lastComponent)")
                continue
            }
        }

        guard let operationTemplate, let protocolTemplate else {
            throw TemplateFilesInitError()
        }

        self.operationTemplate = operationTemplate
        self.protocolTemplate = protocolTemplate
    }

    struct TemplateFilesInitError: Error, CustomStringConvertible {
        let description = "Could not find all expected bundled template files"
    }
}
