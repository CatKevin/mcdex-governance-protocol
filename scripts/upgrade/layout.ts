import { artifacts } from "hardhat";

export async function getStorageLayout(fullyQualifiedName) {
  const [path, name] = fullyQualifiedName.split(":");
  const buildInfo = await artifacts.getBuildInfo(fullyQualifiedName);
  const indexedObjects = flattenObjects(buildInfo.output);
  return parseLayout(indexedObjects, name);
}

/// build index
function flattenObjects(solcOutput) {
  const sources = solcOutput.sources;
  const _search = (root, handler) => {
    if (typeof root === "object" && handler.test(root)) {
      handler.callback(root);
    }
    for (var key in root) {
      const target = root[key];
      if (Array.isArray(target)) {
        for (var i = 0; i < target.length; i++) {
          _search(target[i], handler);
        }
      } else if (typeof target === "object") {
        _search(target, handler);
      }
    }
  };
  const result = {};
  _search(sources, {
    test: (x) => {
      return x != null && "id" in x;
    },
    callback: (x) => {
      result[x.id] = x;
    },
  });
  return result;
}

function find(objects, condition) {
  for (var key in objects) {
    if (condition(objects[key])) {
      return objects[key];
    }
  }
  return undefined;
}

function parseLayout(objects, contractName) {
  const ast = find(objects, (x) => x.nodeType == "ContractDefinition" && x.name == contractName);
  const inheritIDs = ast.linearizedBaseContracts;
  const output = [];
  for (var i = inheritIDs.length - 1; i >= 0; i--) {
    const root = objects[inheritIDs[i]].nodes;
    const layout = parseCompositeType(objects, output, root);
  }
  return output;
}

function parseCompositeType(objects, output, nodes) {
  const definitions = [];
  if (typeof nodes === "undefined") {
    return definitions;
  }
  for (var j = 0; j < nodes.length; j++) {
    var node = nodes[j];
    if (node.nodeType != "VariableDeclaration") {
      continue;
    }
    const typeRef = parseDeclaration(objects, node);
    if (typeof typeRef != "undefined") {
      output.push(typeRef);
    }
  }
  return definitions;
}

function parseDeclaration(objects, node) {
  if (node.constant == true) {
    return undefined;
  }
  const typeRef = {
    id: node.id,
    name: node.name,
    type: node.typeDescriptions.typeIdentifier,
    typeName: node.typeDescriptions.typeString,
    visibility: node.visibility,
  };
  var subRef = null;
  switch (node.typeName.nodeType) {
    // struct
    case "UserDefinedTypeName": {
      subRef = objects[node.typeName.referencedDeclaration];
      break;
    }
    // array
    case "ArrayTypeName": {
      if (typeof node.typeName.length != "undefined") {
        typeRef["length"] = node.typeName.length.value;
      }
      if (node.typeName.baseType.nodeType == "UserDefinedTypeName") {
        subRef = objects[node.typeName.baseType.referencedDeclaration];
      }
      break;
    }
    // map
    case "Mapping": {
      typeRef["keyType"] = node.typeName.keyType.typeDescriptions.typeIdentifier;
      if (node.typeName.valueType.nodeType == "UserDefinedTypeName") {
        subRef = objects[node.typeName.valueType.referencedDeclaration];
      }
      break;
    }
  }
  if (subRef != null && subRef.nodeType != "ContractDefinition") {
    typeRef["subType"] = [];
    parseCompositeType(objects, typeRef["subType"], subRef.members);
  }

  return typeRef;
}
