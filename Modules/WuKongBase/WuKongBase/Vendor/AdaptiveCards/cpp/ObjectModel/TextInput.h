// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseInputElement.h"
#include "ElementParserRegistration.h"

namespace AdaptiveCards
{
class TextInput : public BaseInputElement
{
    friend class TextInputParser;
public:
    TextInput();
    TextInput(const TextInput&) = default;
    TextInput(TextInput&&) = default;
    TextInput& operator=(const TextInput&) = default;
    TextInput& operator=(TextInput&&) = default;
    ~TextInput() = default;

    Json::Value SerializeToJsonValue() const override;

    std::string GetPlaceholder() const;
    void SetPlaceholder(const std::string& value);

    std::string GetValue() const;
    void SetValue(const std::string& value);

    bool GetIsMultiline() const;
    void SetIsMultiline(const bool value);

    unsigned int GetMaxLength() const;
    void SetMaxLength(const unsigned int value);

    TextInputStyle GetTextInputStyle() const;
    void SetTextInputStyle(const TextInputStyle value);

    std::shared_ptr<BaseActionElement> GetInlineAction() const;
    void SetInlineAction(const std::shared_ptr<BaseActionElement> action);

    std::string GetRegex() const;
    void SetRegex(const std::string& value);

    static void addLabel(const std::string& labelId, const std::string& label)
    {
        if (!labelId.empty() && !label.empty()) {
            inputIdToLabelMap[labelId] = label;
        }
    }

    static std::string getLabel(const std::string& labelId)
    {
        if (inputIdToLabelMap.find(labelId) != inputIdToLabelMap.end())
        {
            return inputIdToLabelMap[labelId];
        }
        return "";
    }

    static std::string getLabelForAccessibility(std::shared_ptr<AdaptiveCards::TextInput> textInput) {
        std::string label = "";

        if (textInput != nullptr && textInput.get() != nullptr) {
            auto input = textInput.get();
            auto labelId = input->GetId();

            if (inputIdToLabelMap.find(labelId) != inputIdToLabelMap.end()) {
                label += " " + inputIdToLabelMap[labelId];
            } else if (!input->GetLabel().empty()) {
                label += " " + input->GetLabel();
            }

            label += " " + input->GetPlaceholder();
            if (input->GetIsRequired()) {
                label += " required";
            }
        }

        return label;
    }

    static bool getIsRequired(const std::string& labelId)
    {
        return requiredInputIdSet.find(labelId) != requiredInputIdSet.end();
    }

private:
    static std::unordered_map<std::string, std::string> inputIdToLabelMap;
    static std::unordered_set<std::string> requiredInputIdSet;
    void PopulateKnownPropertiesSet();

    std::string m_placeholder;
    std::string m_value;
    std::string m_regex;
    bool m_isMultiline;
    unsigned int m_maxLength;
    TextInputStyle m_style;
    std::shared_ptr<BaseActionElement> m_inlineAction;
};

class TextInputParser : public BaseCardElementParser
{
public:
    TextInputParser() = default;
    TextInputParser(const TextInputParser&) = default;
    TextInputParser(TextInputParser&&) = default;
    TextInputParser& operator=(const TextInputParser&) = default;
    TextInputParser& operator=(TextInputParser&&) = default;
    virtual ~TextInputParser() = default;

    std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
    std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
};
} // namespace AdaptiveCards
