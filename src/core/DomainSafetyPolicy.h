#pragma once

#include <QString>

class DomainSafetyPolicy
{
  public:
    static bool validate(const QString& xml, const QString& poolPath, QString* error);
};
